#if DEBUG
import Foundation

/// DEBUG-only launch arguments for screenshots and UI checks. `UserDefaults` reads
/// `-key value` pairs from the launch arguments automatically.
///
/// - `-FolioScreen gallery|cover|greeting` opens one screen directly.
/// - `-FolioNow 2026-10-26T08:15` fakes the clock (local time).
/// - `-FolioGreetingHold YES` stops the greeting before it dissolves.
/// - `-displayName Sam` sets the name in the synced settings.
/// - `-FolioResetData YES` erases the local store first.
/// - `-FolioSampleData YES` loads sample data into an empty store.
/// - `-FolioStressData YES` loads 10,000 entries for performance checks.
/// - `-FolioSelectDay 2026-10-25` selects a day on the calendar.
/// - `-FolioFilter Travel` turns on the category filter for that category name.
/// - `-FolioJumpSheet YES` opens the Jump sheet.
/// - `-FolioCollapsed YES` collapses the calendar to the selected week.
/// - `-FolioSkipGreeting YES` skips the launch greeting (UI tests).
/// - `-FolioSeedTask "Title"` adds one task for today (UI tests).
enum DebugLaunchOptions {
    enum Screen: String {
        case gallery, cover, greeting
    }

    static var screen: Screen? {
        UserDefaults.standard.string(forKey: "FolioScreen").flatMap(Screen.init(rawValue:))
    }

    static var skipsGreeting: Bool {
        UserDefaults.standard.bool(forKey: "FolioSkipGreeting")
    }

    static var holdsGreeting: Bool {
        UserDefaults.standard.bool(forKey: "FolioGreetingHold")
    }

    @MainActor
    static func apply(to store: DiaryStore) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "FolioResetData") { store.eraseAll() }
        if defaults.bool(forKey: "FolioSampleData") { PreviewData.loadIfEmpty(into: store) }
        if defaults.bool(forKey: "FolioStressData"), store.isEmpty { PreviewData.loadStressData(into: store) }
        if let title = defaults.string(forKey: "FolioSeedTask") { _ = try? store.createTask(title: title, day: store.today) }
        if let name = defaults.string(forKey: "displayName"), store.settings().displayName != name {
            store.updateSettings { $0.displayName = name }
        }
    }

    @MainActor
    static func apply(to calendar: CalendarModel, store: DiaryStore) {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "FolioSelectDay"), let day = DayKey(rawValue: raw) {
            calendar.jump(to: day.monthKey, selecting: day)
        }
        if let name = defaults.string(forKey: "FolioFilter"),
           let category = store.categories().first(where: { $0.name == name }) {
            calendar.filter = [category.id]
        }
        calendar.showsJumpSheet = defaults.bool(forKey: "FolioJumpSheet")
    }

    static var startsCollapsed: Bool {
        UserDefaults.standard.bool(forKey: "FolioCollapsed")
    }

    static var fakeNow: Date? {
        guard let value = UserDefaults.standard.string(forKey: "FolioNow") else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: value)
    }
}
#endif
