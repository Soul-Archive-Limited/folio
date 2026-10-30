import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("To-do groups and drag rules (Batch I)")
struct TodoGroupingTests {
    let container: ModelContainer
    let store: DiaryStore
    let today = DayKey(rawValue: "2026-10-27")!

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london,
                           now: { TestCalendar.date(2026, 10, 27, 9) })
    }

    @Test("Dates fall into Overdue · Today · Tomorrow · This week · Later · No date", arguments: [
        ("2026-10-20", TodoModel.Group.overdue), ("2026-10-27", .today), ("2026-10-28", .tomorrow),
        ("2026-10-29", .thisWeek), ("2026-11-02", .thisWeek), ("2026-11-03", .later),
    ])
    func groups(day: String, group: TodoModel.Group) {
        #expect(TodoModel.group(for: day, today: today) == group)
    }

    @Test("No date is its own group")
    func noDate() {
        #expect(TodoModel.group(for: nil, today: today) == .noDate)
    }

    @Test("The date pill shows one date's tasks only")
    func dayFilter() throws {
        _ = try store.createTask(title: "A", day: today)
        _ = try store.createTask(title: "B", day: today.adding(days: 1))
        let model = TodoModel(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        model.dayFilter = today.adding(days: 1)
        #expect(model.sections(from: store.allTasks(), today: today).active.map(\.title) == ["B"])
    }

    @Test("Tasks reorder among their own date; a drop onto another date is refused")
    func reorder() throws {
        let a = try store.createTask(title: "A", day: today.adding(days: 2))
        let b = try store.createTask(title: "B", day: today.adding(days: 2))
        let c = try store.createTask(title: "C", day: today.adding(days: 4))
        let model = TodoModel(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let week = try #require(model.sections(from: store.allTasks(), today: today).groups[.thisWeek])
        #expect(week.map(\.title) == ["A", "B", "C"])
        let swapped = try #require(TodoModel.reorder(week, from: [1], to: 0))
        #expect(swapped.map(\.title) == ["B", "A"])
        #expect(TodoModel.reorder(week, from: [0], to: 3) == nil, "A can't move to C's date")
        store.reorderTasks(swapped)
        #expect(model.sections(from: store.allTasks(), today: today).groups[.thisWeek]?.map(\.title) == ["B", "A", "C"])
        _ = (a, b, c)
    }

    @Test("Folded groups are remembered")
    func folding() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        TodoModel(defaults: defaults).toggleFold(.later)
        #expect(TodoModel(defaults: defaults).foldedGroups == [.later])
    }
}
