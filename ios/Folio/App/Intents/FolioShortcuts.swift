import AppIntents

/// Siri phrases and the Shortcuts app's Folio actions (Batch J). Every phrase names the app.
struct FolioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddTaskIntent(), phrases: [
            "Add a task in \(.applicationName)",
            "Add a \(.applicationName) task",
            "Remind me in \(.applicationName)",
        ], shortTitle: "Add Task", systemImageName: "checklist")
        AppShortcut(intent: NewEntryIntent(), phrases: [
            "New \(.applicationName) entry",
            "Write in \(.applicationName)",
            "New page in \(.applicationName)",
        ], shortTitle: "New Entry", systemImageName: "square.and.pencil")
        AppShortcut(intent: DictateEntryIntent(), phrases: [
            "Dictate in \(.applicationName)",
            "Dictate a \(.applicationName) entry",
        ], shortTitle: "Dictate Entry", systemImageName: "mic")
        AppShortcut(intent: ShowTodayIntent(), phrases: [
            "Show today in \(.applicationName)",
            "Open today in \(.applicationName)",
        ], shortTitle: "Show Today", systemImageName: "calendar")
        AppShortcut(intent: OpenOnThisDayIntent(), phrases: [
            "Open On this day in \(.applicationName)",
            "What did I write on this day in \(.applicationName)",
        ], shortTitle: "On This Day", systemImageName: "clock.arrow.circlepath")
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
