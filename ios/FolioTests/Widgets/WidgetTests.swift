import Foundation
import SwiftData
import Testing
@testable import Folio

@Suite("Deep links")
struct FolioRouteTests {
    @Test("Every route round-trips through its URL")
    func roundTrip() {
        let routes: [FolioRoute] = [.newEntry, .newTask, .dictate, .today, .onThisDay, .search, .day("2026-11-05"), .task(UUID())]
        for route in routes { #expect(FolioRoute(url: route.url) == route) }
    }

    @Test("Anything else is ignored")
    func rejects() {
        for raw in ["https://folio.devilsense.com/today", "folio://delete-everything", "folio://day/../../x", "folio://day/2026-11-5x", "folio://task/not-a-uuid", "folio://auth?code=1"] {
            #expect(FolioRoute(url: URL(string: raw)!) == nil, "\(raw)")
        }
    }
}

@MainActor
@Suite("Widget snapshot and intents")
struct WidgetSnapshotTests {
    let container: ModelContainer
    let store: DiaryStore

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 11, 5, 9) })
    }

    @Test("Today's and tomorrow's tasks, open overdue ones, a month grid; no done overdue tasks")
    func snapshot() throws {
        let today = store.today
        try store.createTask(title: "Today", day: today, minutesFromMidnight: 600)
        try store.createTask(title: "Tomorrow", day: today.adding(days: 1))
        try store.createTask(title: "Late", day: today.adding(days: -3))
        let doneLate = try store.createTask(title: "Done late", day: today.adding(days: -2))
        store.setCompleted(doneLate, true)
        try store.createTask(title: "Next week", day: today.adding(days: 7))
        try store.createEntry(title: "Page", body: "", day: today)

        let snapshot = WidgetSnapshotWriter.makeSnapshot(store: store)
        #expect(Set(snapshot.tasks.map(\.title)) == ["Today", "Tomorrow", "Late"])
        #expect(snapshot.tasks.first { $0.title == "Today" }?.minutes == 600)
        #expect(snapshot.months.count == 2)
        #expect(snapshot.months[0].grid.count == 42)
        #expect(snapshot.months[0].days[today.rawValue]?.entries == 1)
        #expect(snapshot.greetings.count == 5)
    }

    @Test("Add Task (Siri/Shortcuts) adds to the store, with a day and a time when given")
    func addTaskIntent() async throws {
        AppServices.store = store
        defer { AppServices.store = nil }
        let intent = AddTaskIntent()
        intent.title = "  Buy stamps "
        intent.date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 18, minute: 30))
        _ = try await intent.perform()
        let task = try #require(store.allTasks().first { $0.title == "Buy stamps" })
        #expect(task.dayKey == "2026-11-06")
        #expect(task.minutesFromMidnight == 18 * 60 + 30)
    }
}
