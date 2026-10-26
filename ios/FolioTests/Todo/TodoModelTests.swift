import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("To-do (SPEC §6.7)")
struct TodoModelTests {
    let container: ModelContainer
    let store: DiaryStore
    let model = TodoModel()

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london,
                           now: { TestCalendar.date(2026, 10, 27, 9) })
    }

    @Test("Active is overdue → dated ascending → undated by drag order; Completed newest first")
    func ordering() throws {
        let today = store.today
        let undatedB = try store.createTask(title: "Undated B")
        let later = try store.createTask(title: "Next week", day: today.adding(days: 7))
        let overdue = try store.createTask(title: "Overdue", day: today.adding(days: -2))
        let todayTask = try store.createTask(title: "Today", day: today)
        let undatedA = try store.createTask(title: "Undated A")
        store.reorderTasks([undatedA, undatedB])
        let doneFirst = try store.createTask(title: "Done first", day: today)
        store.setCompleted(doneFirst, true)
        let doneSecond = try store.createTask(title: "Done second")
        store.setCompleted(doneSecond, true)
        doneSecond.completedAt = doneFirst.completedAt?.addingTimeInterval(60)

        let sections = model.sections(from: store.allTasks(), today: today)
        #expect(sections.active.map(\.title) == [overdue.title, todayTask.title, later.title, "Undated A", "Undated B"])
        #expect(sections.completed.map(\.title) == ["Done second", "Done first"])
    }

    @Test("A ticked task stays in Active for 1.2 s, then moves to Completed")
    func tickPausesThenMoves() async throws {
        let task = try store.createTask(title: "Post letter", day: store.today)
        #expect(model.toggle(task, store: store))
        #expect(model.isTicked(task) && task.isCompleted)
        #expect(model.sections(from: store.allTasks(), today: store.today).active.contains { $0.id == task.id })
        try await Task.sleep(for: .milliseconds(1500))
        let sections = model.sections(from: store.allTasks(), today: store.today)
        #expect(sections.completed.map(\.id) == [task.id])
        #expect(store.tasks(on: store.today).map(\.id) == [task.id], "still on its day")
    }

    @Test("Tapping again during the pause cancels the tick")
    func cancelDuringPause() async throws {
        let task = try store.createTask(title: "Oops", day: store.today)
        model.toggle(task, store: store)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!model.toggle(task, store: store))
        #expect(!task.isCompleted && !model.isTicked(task))
        try await Task.sleep(for: .milliseconds(1300))
        #expect(model.sections(from: store.allTasks(), today: store.today).completed.isEmpty)
    }

    @Test("Undo works during the pause and after the move; unticking in Completed is instant")
    func undo() async throws {
        let task = try store.createTask(title: "Call Mum")
        model.toggle(task, store: store)
        model.undo(task, store: store)
        #expect(!task.isCompleted)

        model.toggle(task, store: store)
        try await Task.sleep(for: .milliseconds(1500))
        model.undo(task, store: store)
        #expect(!task.isCompleted)

        store.setCompleted(task, true)
        #expect(!model.toggle(task, store: store), "untick in Completed")
        #expect(!task.isCompleted)
    }

    @Test("Category filter applies to Active and Completed")
    func filter() throws {
        let work = try store.createCategory(name: "Work", color: .graphite)
        _ = try store.createTask(title: "Work task", categoryID: work.id)
        _ = try store.createTask(title: "Other")
        model.filter = [work.id]
        #expect(model.sections(from: store.allTasks(), today: store.today).active.map(\.title) == ["Work task"])
    }
}

@Suite("Quick add (SPEC §6.7)")
struct QuickAddParserTests {
    let today = DayKey(year: 2026, month: 10, day: 27)!

    @Test("Recognises today and tomorrow at either end", arguments: [
        ("Call Mum tomorrow", "Call Mum", 1), ("tomorrow call Mum", "call Mum", 1),
        ("Pay rent today", "Pay rent", 0), ("Buy milk Today.", "Buy milk", 0),
    ])
    func dated(text: String, title: String, offset: Int) {
        #expect(QuickAddParser.parse(text, today: today) == .init(title: title, day: today.adding(days: offset)))
    }

    @Test("Leaves everything else alone", arguments: ["Read today's paper", "Tomorrowland tickets", "today", "Water plants"])
    func undated(text: String) {
        #expect(QuickAddParser.parse(text, today: today).day == nil)
        #expect(QuickAddParser.parse(text, today: today).title == text)
    }
}
