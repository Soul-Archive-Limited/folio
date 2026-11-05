import AppIntents
import Foundation

// Intents shared by the app (Siri, Shortcuts, Action Button) and the widget extension
// (Control Center, widgets) — Batch J. The "open" ones only return a `folio://` link, so they
// work from any process; the app routes it (and Lock Folio covers it first).

nonisolated struct NewEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "New Entry"
    static let description = IntentDescription("Opens Folio with a new page for today.")
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(FolioRoute.newEntry.url))
    }
}

nonisolated struct DictateEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Dictate Entry"
    static let description = IntentDescription("Opens a new page for today and starts dictation. Your voice is turned into text on this device, never sent anywhere.")
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(FolioRoute.dictate.url))
    }
}

nonisolated struct OpenNewTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task in Folio"
    static let description = IntentDescription("Opens Folio's quick add for a new task.")
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(FolioRoute.newTask.url))
    }
}

nonisolated struct ShowTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Today"
    static let description = IntentDescription("Opens Folio on today's pages and tasks.")
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(FolioRoute.today.url))
    }
}

nonisolated struct OpenOnThisDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Open On This Day"
    static let description = IntentDescription("Shows what you wrote on today's date in earlier years.")
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(FolioRoute.onThisDay.url))
    }
}

/// The tick on the Today widget: queued for the app, shown done at once.
struct ToggleWidgetTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Tick Task"
    static let isDiscoverable = false

    @Parameter(title: "Task") var taskID: String
    @Parameter(title: "Done") var isDone: Bool

    init() {}

    init(taskID: UUID, isDone: Bool) {
        self.taskID = taskID.uuidString
        self.isDone = isDone
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { return .result() }
        WidgetActionQueue.append(.init(taskID: id, isDone: isDone, at: .now))
        // Show it at once; the app's next snapshot replaces this.
        if var snapshot = WidgetSnapshot.load(), let index = snapshot.tasks.firstIndex(where: { $0.id == id }) {
            snapshot.tasks[index].isDone = isDone
            if let url = WidgetSnapshot.url, let data = snapshot.encoded() { try? AppGroup.write(data, to: url) }
        }
        return .result()
    }
}
