import Foundation
import os
import UIKit

/// Keeps the on-device store and the account's encrypted copy in step (SPEC §10.5).
///
/// When it syncs: once the account is ready (full pull, then the guest diary is pushed with
/// progress), 2 s after the last local edit (push), when the live socket reports a cursor the
/// device hasn't pulled yet, from "Sync now", and in background refresh. Everything else —
/// opening the app with nothing new — costs one socket connection and no pull.
@Observable
final class SyncEngine {
    enum Status: Equatable {
        case upToDate, syncing, offline, error
    }

    private(set) var status: Status = .upToDate
    private(set) var lastSynced: Date?
    /// Records pushed / to push while a big first upload runs (guest → account).
    private(set) var progress: (done: Int, total: Int)?
    /// Entries in that first upload ("Encrypting and syncing 412 pages…").
    private(set) var migratingPages: Int?

    @ObservationIgnored let store: DiaryStore
    @ObservationIgnored unowned let account: AccountModel
    @ObservationIgnored weak var toasts: ToastCenter?
    @ObservationIgnored let logger = Logger(subsystem: "com.devilsense.folio", category: "sync")

    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var wantsPull = false
    @ObservationIgnored private var wantsAnotherPass = false
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var retry: Task<Void, Never>?
    @ObservationIgnored private var backoff = SyncBackoff()
    @ObservationIgnored private var socket: LiveSocket?
    @ObservationIgnored var isForeground = false
    /// Blob ids that failed to download this launch, so a missing blob isn't asked for again.
    @ObservationIgnored var failedDownloads: Set<String> = []

    static let debounceDelay: Duration = .seconds(2)

    init(store: DiaryStore, account: AccountModel) {
        self.store = store
        self.account = account
        account.sync = self
        store.onLocalChange = { [weak self] in self?.localChange() }
        store.onErase = { [weak self] in self?.storeErased() }
        if let userID = account.userID { lastSynced = SyncState.lastSynced(for: userID) }
    }

    var isActive: Bool { account.status == .ready }

    // MARK: Lifecycle

    func accountBecameReady(joinedExisting: Bool) {
        if joinedExisting { store.letAccountSettingsWin() }
        lastSynced = account.userID.flatMap(SyncState.lastSynced(for:))
        requestSync(pull: true)
        if isForeground { openSocket() }
        Task { await account.reportDeviceNameIfNeeded() }
    }

    /// App came to the foreground: open the live socket (its first message says whether
    /// there's anything to pull) and push anything still waiting.
    func enterForeground() {
        isForeground = true
        guard isActive else { return }
        openSocket()
        Task { await account.reportDeviceNameIfNeeded() }
        if store.hasDirtyRecords || !store.photosNeedingUpload().isEmpty { requestSync(pull: false) }
    }

    /// The socket closes in the background (SPEC §10.5).
    func enterBackground() {
        isForeground = false
        socket?.close()
        socket = nil
    }

    /// Signed out or deleted: stop everything.
    func stop() {
        debounce?.cancel()
        retry?.cancel()
        running?.cancel()
        running = nil
        socket?.close()
        socket = nil
        status = .upToDate
        progress = nil
        migratingPages = nil
        lastSynced = nil
        failedDownloads = []
    }

    /// The local copy was erased while signed in: start again from the account's copy.
    func storeErased() {
        guard let userID = account.userID else { return }
        SyncState.setCursor(0, for: userID)
        failedDownloads = []
        requestSync(pull: true)
    }

    // MARK: Triggers

    func localChange() {
        guard isActive else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceDelay)
            guard !Task.isCancelled else { return }
            self?.requestSync(pull: false)
        }
    }

    /// Profile → "Sync now": pull and push, waiting for the result.
    func syncNow() async {
        requestSync(pull: true)
        await running?.value
    }

    /// Background refresh (only while protected data is available, DECISIONS 100).
    func backgroundRefresh() async {
        guard isActive else { return }
        requestSync(pull: true)
        await running?.value
    }

    func requestSync(pull: Bool) {
        guard isActive else { return }
        wantsPull = wantsPull || pull
        if running != nil {
            wantsAnotherPass = true
            return
        }
        retry?.cancel()
        running = Task { [weak self] in
            await self?.runPasses()
        }
    }

    private func runPasses() async {
        repeat {
            wantsAnotherPass = false
            let pull = wantsPull
            wantsPull = false
            await runPass(pull: pull)
        } while wantsAnotherPass && !Task.isCancelled && isActive
        running = nil
    }

    private func runPass(pull: Bool) async {
        guard let userID = account.userID, let key = account.dataKey else { return }
        status = .syncing
        startProgressIfLarge()
        do throws(APIError) {
            if pull { try await self.pull(userID: userID, key: key) }
            // Records first, so a photo upload that hits a limit never holds back the text.
            try await push(userID: userID, key: key)
            try await uploadPendingBlobs(userID: userID, key: key)
            try await push(userID: userID, key: key)
            try await downloadPendingBlobs(userID: userID, key: key)
            backoff.reset()
            status = .upToDate
            lastSynced = .now
            SyncState.setLastSynced(.now, for: userID)
            progress = nil
            migratingPages = nil
        } catch .unauthorized {
            account.sessionEnded()
        } catch {
            // Waiting out a rate limit is still syncing; no connection is offline.
            if case .rateLimited = error { status = .syncing } else { status = error.isTransient ? .offline : .error }
            if error.isTransient {
                scheduleRetry(after: error, pull: pull)
            } else {
                progress = nil
                migratingPages = nil
            }
            logger.notice("Sync pass failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// A big first upload (a guest diary joining an account) shows progress: records plus photos.
    private func startProgressIfLarge() {
        guard progress == nil else { return }
        let records = store.dirtyRecords()
        let photos = store.photosNeedingUpload().count
        guard records.count + photos > 50 else { return }
        progress = (0, records.count + photos)
        migratingPages = records.count { $0 is Entry }
    }

    func advanceProgress(by count: Int) {
        guard let current = progress else { return }
        progress = (min(current.done + count, current.total), current.total)
    }

    private func scheduleRetry(after error: APIError, pull: Bool) {
        var retryAfter: TimeInterval?
        if case .rateLimited(let seconds) = error { retryAfter = seconds }
        let delay = backoff.nextDelay(retryAfter: retryAfter)
        retry?.cancel()
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.requestSync(pull: pull)
        }
    }

    // MARK: Live socket

    private func openSocket() {
        guard socket == nil, isActive, let token = account.api.currentToken else { return }
        let socket = LiveSocket(url: account.api.webSocketURL, token: token)
        socket.onCursor = { [weak self] cursor in self?.remoteCursor(cursor) }
        socket.onClose = { [weak self] rejected in self?.socketClosed(rejected: rejected) }
        self.socket = socket
        socket.connect()
    }

    private func remoteCursor(_ cursor: Int64) {
        guard let userID = account.userID else { return }
        if cursor != SyncState.cursor(for: userID) {
            requestSync(pull: true)
        } else if running == nil && !store.hasDirtyRecords {
            // The server has nothing newer: this device is in sync as of now.
            status = .upToDate
            lastSynced = .now
            SyncState.setLastSynced(.now, for: userID)
        }
    }

    private func socketClosed(rejected: Bool) {
        socket = nil
        guard isForeground, isActive else { return }
        // Refused: the session ended elsewhere (signed out, account deleted). A pull confirms it
        // with the API, whose 401 signs this device out and keeps the diary — instead of
        // reconnecting forever while showing "Up to date" (found in Batch I's two-device test).
        if rejected {
            requestSync(pull: true)
            return
        }
        // Reconnect after a pause; a dropped socket while offline shows as Offline.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double.random(in: 5...15)))
            guard let self, self.isForeground, self.socket == nil else { return }
            self.openSocket()
        }
    }
}
