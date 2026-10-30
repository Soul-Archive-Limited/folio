import Foundation
import Observation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Appearance settings apply at once and match the Settings app (Batch I)")
struct SettingsBridgeTests {
    let container: ModelContainer
    let store: DiaryStore
    let defaults: UserDefaults

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london,
                           now: { TestCalendar.date(2026, 10, 27, 9) })
        defaults = try #require(UserDefaults(suiteName: "SettingsBridgeTests-\(UUID().uuidString)"))
    }

    @Test("Reading settings registers observation, so pickers and the theme redraw on change")
    func settingsAreObserved() {
        _ = store.settings()
        nonisolated final class Flag: @unchecked Sendable { var value = false }
        let changed = Flag()
        withObservationTracking { _ = store.settings().appearance } onChange: { changed.value = true }
        store.updateSettings { $0.appearance = AppearancePreference.dark.rawValue }
        #expect(changed.value)
    }

    @Test("The app's values are mirrored into Settings on first run")
    func mirrorsAppValues() {
        store.updateSettings { $0.writingFont = WritingFont.sfPro.rawValue; $0.firstWeekday = 2 }
        let bridge = SystemSettingsBridge(defaults: defaults)
        bridge.reconcile(with: store)
        #expect(bridge.systemValues == .init(theme: "system", writingFont: "sfPro", firstWeekday: 2))
    }

    @Test("A change made in the Settings app wins and reaches the synced settings")
    func settingsAppChangeApplies() {
        let bridge = SystemSettingsBridge(defaults: defaults)
        bridge.reconcile(with: store)
        defaults.set("dark", forKey: SystemSettingsBridge.Key.theme)
        defaults.set(1, forKey: SystemSettingsBridge.Key.firstWeekday)
        bridge.reconcile(with: store)
        #expect(store.settings().appearance == "dark")
        #expect(store.settings().firstWeekday == 1)
        #expect(store.settings().isDirty, "it syncs to the other devices")
    }

    @Test("A change from the app or another device overwrites Settings")
    func appChangeMirrors() {
        let bridge = SystemSettingsBridge(defaults: defaults)
        bridge.reconcile(with: store)
        store.updateSettings { $0.appearance = "light"; $0.firstWeekday = nil }
        bridge.reconcile(with: store)
        #expect(bridge.systemValues.theme == "light")
        #expect(bridge.systemValues.firstWeekday == 0)
    }

    @Test("Unknown values from Settings fall back safely")
    func unknownValues() {
        defaults.set("sepia", forKey: SystemSettingsBridge.Key.theme)
        defaults.set(9, forKey: SystemSettingsBridge.Key.firstWeekday)
        let values = SystemSettingsBridge(defaults: defaults).systemValues
        #expect(values.theme == "system")
        #expect(values.firstWeekday == 0)
    }
}

@Suite("App-switcher cover line (Batch I)")
struct PrivacyCoverLineTests {
    @Test("A new line never repeats the last one")
    func neverRepeats() {
        var generator = SeededGenerator(seed: 7)
        var last: Int?
        for _ in 0..<500 {
            let next = PrivacyCoverLines.next(after: last, using: &generator)
            #expect(next != last)
            #expect((0..<PrivacyCoverLines.count).contains(next))
            last = next
        }
    }

    @Test("Every line has a named and an unnamed form")
    func namedAndUnnamed() {
        for index in 0..<PrivacyCoverLines.count {
            #expect(PrivacyCoverLines.line(index, name: "Sam").contains("Sam"))
            #expect(!PrivacyCoverLines.line(index, name: "  ").contains(","))
        }
    }
}
