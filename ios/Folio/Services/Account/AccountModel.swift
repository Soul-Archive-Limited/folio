import FolioCrypto
import Foundation
import os

/// Who is signed in on this device, and whether the diary key is here (SPEC §6.1 steps 5–7,
/// §10.2–10.4). Guest mode is the default; nothing here is needed to use the app.
///
/// - `settingUp`: a new account, or one without a recovery key yet; the recovery key screen
///   shows until the person confirms they saved it.
/// - `locked`: signed in, but this device doesn't have the Data Key (no iCloud Keychain copy);
///   the unlock screen offers a QR from another device or the recovery key.
/// - `ready`: signed in with the key; sync runs.
@Observable
final class AccountModel {
    enum Status: Equatable {
        case guest, settingUp, locked, ready
    }

    private(set) var status: Status = .guest
    private(set) var session: StoredSession?
    /// The recovery key being shown during set-up; cleared once it's confirmed.
    private(set) var pendingRecoveryKey: RecoveryKey?
    /// Set when a sign-in joined an account that already existed (so its synced settings win).
    private(set) var joinedExistingAccount = false
    /// When the current session last re-authenticated (delete account needs ≤ 10 minutes).
    private(set) var reauthenticatedAt: Date?

    @ObservationIgnored private(set) var dataKey: DataKey?
    @ObservationIgnored let api: APIClient
    /// The sync engine, told when the key arrives and when the session ends.
    @ObservationIgnored weak var sync: SyncEngine?
    @ObservationIgnored let logger = Logger(subsystem: "com.devilsense.folio", category: "account")

    init(api: APIClient = APIClient(), restore: Bool = true) {
        self.api = api
        guard restore, let stored = StoredSession.load() else { return }
        session = stored
        api.setToken(stored.token)
        if let key = Self.storedDataKey(for: stored.userID) {
            dataKey = key
            status = .ready
        } else {
            status = .locked
        }
    }

    var userID: UUID? { session?.userID }
    var isSignedIn: Bool { status != .guest }

    // MARK: After any sign-in

    /// Saves the session and works out what this device still needs: nothing (key in iCloud
    /// Keychain), a new recovery key (new account), or an unlock (existing account).
    func completeSignIn(_ result: AccountAPI.SignIn, appleUserID: String? = nil) {
        var stored = StoredSession(token: result.token, sessionID: result.sessionId, userID: result.userId)
        stored.appleUserID = appleUserID
        stored.save()
        api.setToken(result.token)
        session = stored
        joinedExistingAccount = !result.isNew
        reauthenticatedAt = .now

        if let key = Self.storedDataKey(for: result.userId) {
            dataKey = key
            if result.hasRecoveryKey {
                becomeReady()
            } else {
                pendingRecoveryKey = Keychain.data(for: .recoveryKey(userID: result.userId))
                    .flatMap { String(data: $0, encoding: .utf8) }
                    .flatMap { try? RecoveryKey(string: $0) } ?? .generate()
                status = .settingUp
            }
        } else if !result.hasRecoveryKey {
            dataKey = .generate()
            pendingRecoveryKey = .generate()
            status = .settingUp
        } else {
            status = .locked
        }
        Task { await refreshMe() }
    }

    func noteReauthenticated() {
        reauthenticatedAt = .now
    }

    func updateStoredSession(_ stored: StoredSession) {
        stored.save()
        session = stored
    }

    func resetToGuest() {
        status = .guest
        session = nil
        dataKey = nil
        pendingRecoveryKey = nil
        joinedExistingAccount = false
        reauthenticatedAt = nil
    }

    // MARK: Keys

    /// The person confirmed the last four characters: upload the wrapped key, keep both keys
    /// in iCloud Keychain, start syncing.
    func confirmRecoveryKeySaved() async throws(APIError) {
        guard let userID, let dataKey, let recovery = pendingRecoveryKey else { return }
        guard let envelope = try? RecoveryKeyWrapper.wrap(dataKey, with: recovery, userID: userID) else { throw .invalidResponse }
        do throws(APIError) {
            let _: OKResponse = try await api.send("PUT", "keys/recovery",
                                                   json: AccountAPI.RecoveryEnvelope(envelope: envelope.wireData.base64EncodedString()))
        } catch .server(409, _) {
            // Another device finished set-up first: its key is the account's key.
            guard (try? await unwrapServerEnvelope(with: recovery)) != nil else {
                pendingRecoveryKey = nil
                self.dataKey = nil
                status = .locked
                return
            }
        }
        store(dataKey: dataKey, recoveryKey: recovery, for: userID)
        pendingRecoveryKey = nil
        becomeReady()
    }

    /// Unlock with the recovery key typed or pasted on this device.
    func unlock(recoveryKeyText text: String) async throws(UnlockError) {
        let recovery: RecoveryKey
        do { recovery = try RecoveryKey(string: text) } catch { throw .malformed }
        guard let userID else { return }
        let key: DataKey
        do {
            key = try await unwrapServerEnvelope(with: recovery)
        } catch let error as UnlockError {
            throw error
        } catch {
            throw .network
        }
        store(dataKey: key, recoveryKey: recovery, for: userID)
        becomeReady()
    }

    /// Unlock with the key another device sent through a QR link.
    func unlock(with key: DataKey) {
        guard let userID else { return }
        store(dataKey: key, recoveryKey: nil, for: userID)
        becomeReady()
    }

    /// The recovery key kept on this device (Profile → Recovery key), if it has one.
    var storedRecoveryKey: RecoveryKey? {
        guard let userID else { return nil }
        return Keychain.data(for: .recoveryKey(userID: userID))
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap { try? RecoveryKey(string: $0) }
    }

    private func unwrapServerEnvelope(with recovery: RecoveryKey) async throws -> DataKey {
        guard let userID else { throw UnlockError.network }
        let response: AccountAPI.RecoveryEnvelope
        do throws(APIError) {
            response = try await api.send("GET", "keys/recovery")
        } catch .server(404, _) {
            throw UnlockError.noEnvelope
        }
        guard let wire = Data(base64Encoded: response.envelope),
              let envelope = try? KeyEnvelope(wireData: wire) else { throw UnlockError.noEnvelope }
        do {
            return try RecoveryKeyWrapper.unwrap(envelope, with: recovery, userID: userID)
        } catch {
            throw UnlockError.wrongKey
        }
    }

    private func store(dataKey: DataKey, recoveryKey: RecoveryKey?, for userID: UUID) {
        Keychain.set(dataKey.rawRepresentation, for: .dataKey(userID: userID))
        if let recoveryKey { Keychain.set(Data(recoveryKey.string.utf8), for: .recoveryKey(userID: userID)) }
        self.dataKey = dataKey
    }

    private func becomeReady() {
        status = .ready
        sync?.accountBecameReady(joinedExisting: joinedExistingAccount)
    }

    static func storedDataKey(for userID: UUID) -> DataKey? {
        Keychain.data(for: .dataKey(userID: userID)).flatMap { try? DataKey(rawRepresentation: $0) }
    }
}

/// Why an unlock didn't work, in words the unlock screen can show.
enum UnlockError: Error, Equatable {
    case malformed, wrongKey, noEnvelope, network
}
