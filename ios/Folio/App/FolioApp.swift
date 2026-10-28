import os
import SwiftData
import SwiftUI
import UIKit

@main
struct FolioApp: App {
    private let container: ModelContainer
    @State private var store: DiaryStore
    @State private var account: AccountModel
    @State private var sync: SyncEngine

    init() {
        let container: ModelContainer
        do {
            container = try FolioPersistence.makeContainer()
        } catch {
            // Keep the app usable rather than crashing; nothing is written to the broken store.
            FolioPersistence.logger.fault("Persistent store failed to open: \(String(describing: type(of: error)), privacy: .public)")
            container = (try? FolioPersistence.makeContainer(inMemory: true))
                ?? { fatalError("SwiftData could not create even an in-memory store") }()
        }
        self.container = container
        TourModel.configure()
        let store = DiaryStore(context: container.mainContext, trashClockDefaults: .standard)
        #if DEBUG
        DebugLaunchOptions.apply(to: store)
        #endif
        _store = State(initialValue: store)
        let account = AccountModel()
        _account = State(initialValue: account)
        _sync = State(initialValue: SyncEngine(store: store, account: account))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                .environment(account)
                .environment(sync)
                .modelContainer(container)
        }
        .backgroundTask(.appRefresh(TrashMaintenance.refreshTaskID)) { [store, account, sync] in
            await Self.backgroundRefresh(store: store, account: account, sync: sync)
        }
    }

    /// The purge and, when signed in, a sync — only while the store's files are readable
    /// (DECISIONS 100).
    private static func backgroundRefresh(store: DiaryStore, account: AccountModel, sync: SyncEngine) async {
        TrashMaintenance.purgeIfPossible(store)
        if UIApplication.shared.isProtectedDataAvailable { await sync.backgroundRefresh() }
        TrashMaintenance.scheduleRefresh(signedIn: account.isSignedIn)
    }
}
