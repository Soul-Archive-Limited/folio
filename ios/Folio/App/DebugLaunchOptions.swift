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
/// - `-FolioTab calendar|journal|todo|profile` opens a tab.
/// - `-FolioJournalMode photos` opens the Journal's Photos view.
/// - `-FolioTodoFilter Family` filters the To-do list by a category name.
/// - `-FolioOpen composer|composerLarge|taskComposer|entry|categories|categoryEdit` opens a screen
///   (composerLarge and entry use the selected day's first entry; categoryEdit edits the first category).
/// - `-FolioTourStep N` resets TipKit and starts the tour at step N (1–6).
/// - `-FolioOnboardingPage N` opens onboarding at page N (0–4) when it shows.
/// - `-FolioDemo dictation|intelligence` scripted dictation / canned ✦ results (screenshots).
/// - `-FolioOpenTool mic|titles|polish|tasks` opens that tool in the composer.
/// - `-FolioFakeIntelligenceUnavailable YES` pretends Apple's model is unavailable.
/// - `-FolioToastSeconds 15` keeps toasts up longer (UI tests on slow CI).
/// - `-FolioTrashSamples YES` puts a few sample items in Recently Deleted.
/// - `-FolioOpen recentlyDeleted` (with `-FolioTab profile`) opens Recently Deleted.
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
        if defaults.bool(forKey: "FolioTrashSamples") { PreviewData.trashSamples(in: store) }
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

    static var tab: AppTab? {
        switch UserDefaults.standard.string(forKey: "FolioTab") {
        case "calendar": .calendar
        case "journal": .journal
        case "todo": .todo
        case "profile": .profile
        default: nil
        }
    }

    static func string(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
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
