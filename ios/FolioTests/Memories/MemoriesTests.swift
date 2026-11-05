import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Memories")
struct MemoriesTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 11, 5, 7) })
    }

    private func day(_ raw: String) throws -> DayKey { try #require(DayKey(rawValue: raw)) }

    @Test("Mood is in the encrypted payload; a value off the scale is dropped on arrival")
    func moodPayload() throws {
        let entry = try store.createEntry(title: "Walk", body: "", day: day("2026-11-05"))
        store.setMood(entry, .good)
        let json = try JSONSerialization.jsonObject(with: store.payload(of: entry)) as? [String: Any]
        #expect(json?["mood"] as? Int == 4)

        var payload = try RecordPayload.decoder.decode(RecordPayload.Entry.self, from: store.payload(of: entry))
        payload.mood = 9
        #expect(Mood(rawValue: payload.mood ?? 0) == nil)
    }

    @Test("Year in Pixels: the latest mood, the first category, all the day's pages")
    func pixels() throws {
        let travel = try store.createCategory(name: "Travel", color: .ocean)
        let first = try store.createEntry(title: "Morning", body: "", day: day("2026-03-01"), minutesFromMidnight: 480, categoryID: travel.id)
        let second = try store.createEntry(title: "Evening", body: "", day: day("2026-03-01"), minutesFromMidnight: 1200)
        store.setMood(first, .low)
        store.setMood(second, .bright)
        try store.createEntry(title: "Last year", body: "", day: day("2025-03-01"))
        let pixels = store.yearPixels(2026)
        #expect(pixels.count == 1)
        #expect(pixels["2026-03-01"]?.mood == .bright)
        #expect(pixels["2026-03-01"]?.categoryID == travel.id)
        #expect(pixels["2026-03-01"]?.entryIDs.count == 2)
        #expect(store.firstYearWritten == 2025)
    }

    @Test("On this day notifications: only days with earlier-year pages, the latest year, never a past time")
    func notificationPlan() throws {
        try store.createEntry(title: "", body: "", day: day("2024-11-05"))
        try store.createEntry(title: "", body: "", day: day("2025-11-05"))
        try store.createEntry(title: "", body: "", day: day("2023-11-08"))
        try store.createEntry(title: "", body: "", day: day("2026-11-07")) // this year: not a memory
        let now = TestCalendar.date(2026, 11, 5, 7)
        let plan = OnThisDayNotifier.plan(store: store, now: now, minutes: 8 * 60, calendar: TestCalendar.london)
        #expect(plan.map(\.day.rawValue) == ["2026-11-05", "2026-11-08"])
        #expect(plan.first?.year == 2025)
        let late = OnThisDayNotifier.plan(store: store, now: TestCalendar.date(2026, 11, 5, 9), minutes: 8 * 60, calendar: TestCalendar.london)
        #expect(late.map(\.day.rawValue) == ["2026-11-08"])
    }

    @Test("Composer drafts keep the mood")
    func draftMood() {
        let draft = ComposerDraft(entryID: nil, dayKey: "2026-11-05", minutesFromMidnight: nil, title: "", bodyMarkdown: "x",
                                  categoryID: nil, savedAt: .now).withMood(5)
        #expect(!draft.hasSameContent(as: draft.withMood(nil)))
        let decoded = try? JSONDecoder().decode(ComposerDraft.self, from: JSONEncoder().encode(draft))
        #expect(decoded?.mood == 5)
    }
}
