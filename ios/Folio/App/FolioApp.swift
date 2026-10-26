import os
import SwiftData
import SwiftUI

@main
struct FolioApp: App {
    private let container: ModelContainer
    @State private var store: DiaryStore

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
        let store = DiaryStore(context: container.mainContext)
        #if DEBUG
        DebugLaunchOptions.apply(to: store)
        #endif
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                .modelContainer(container)
        }
    }
}
