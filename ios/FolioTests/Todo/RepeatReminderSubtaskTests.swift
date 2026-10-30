import Foundation
import SwiftData
import Testing
@testable import Folio

@MainActor
@Suite("Repeating tasks, reminders and subtasks (Batch I)")
struct RepeatReminderSubtaskTests {
    let container: ModelContainer
    let store: DiaryStore
    let today = DayKey(rawValue: "2026-10-30")!  // a Friday

    init() throws {
        container = try FolioPersistence.makeContainer(inMemory: true)
        store = DiaryStore(context: container.mainContext, calendar: TestCalendar.london, now: { TestCalendar.date(2026, 10, 30, 9) })
    }

    @Test("Next dates", arguments: [
        (RepeatRule(frequency: .daily), "2026-10-31"),
        (RepeatRule(frequency: .weekdays), "2026-11-02"),
        (RepeatRule(frequency: .weekly), "2026-11-06"),
        (RepeatRule(frequency: .monthly), "2026-11-30"),
        (RepeatRule(frequency: .yearly), "2027-10-30"),
        (RepeatRule(frequency: .custom, interval: 3, unit: .day), "2026-11-02"),
        (RepeatRule(frequency: .custom, interval: 2, unit: .week), "2026-11-13"),
        (RepeatRule(frequency: .custom, interval: 4, unit: .month), "2027-02-28"),
    ])
    func next(rule: RepeatRule, expected: String) {
        #expect(rule.next(after: today).rawValue == expected)
    }

    @Test("31 January monthly lands on the last day of February")
    func monthEnd() {
        #expect(RepeatRule(frequency: .monthly).next(after: DayKey(rawValue: "2027-01-31")!).rawValue == "2027-02-28")
    }

    @Test("Rules round-trip as JSON the web reads")
    func json() throws {
        let rule = RepeatRule(frequency: .custom, interval: 2, unit: .week)
        #expect(rule.json == #"{"frequency":"custom","interval":2,"unit":"week"}"#)
        #expect(RepeatRule.decode(rule.json) == rule)
        #expect(RepeatRule.decode("nonsense") == nil)
    }

    @Test("Ticking a repeating task keeps it done and adds the next, once")
    func repeats() throws {
        let task = try store.createTask(title: "Water plants", day: today, minutesFromMidnight: 8 * 60)
        store.setRepeat(task, RepeatRule(frequency: .weekly))
        store.setReminder(task, ReminderTime(day: today, minutes: 8 * 60))
        store.setCompleted(task, true)
        let next = try #require(store.tasks(on: today.adding(days: 7)).first)
        #expect(task.isCompleted && store.tasks(on: today).contains { $0.id == task.id }, "it stays on its day, ticked")
        #expect(next.title == "Water plants" && !next.isCompleted && next.minutesFromMidnight == 480)
        #expect(next.remindAt == "2026-11-06T08:00", "the reminder moves by the same week")
        store.setCompleted(task, false)
        store.setCompleted(task, true)
        #expect(store.tasks(on: today.adding(days: 7)).count == 1, "no duplicate on a re-tick")
    }

    @Test("Floating reminder times survive a time-zone change")
    func floating() throws {
        let time = try #require(ReminderTime(rawValue: "2026-11-02T18:30"))
        #expect(time.rawValue == "2026-11-02T18:30")
        var kolkata = Calendar(identifier: .gregorian)
        kolkata.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let london = TestCalendar.london
        let inIndia = try #require(time.date(in: kolkata)), inLondon = try #require(time.date(in: london))
        #expect(kolkata.component(.hour, from: inIndia) == 18 && london.component(.hour, from: inLondon) == 18)
        #expect(ReminderTime(rawValue: "2026-11-02T25:00") == nil)
    }

    @Test("Only future, open, live reminders are scheduled, nearest first")
    func plan() throws {
        let later = try store.createTask(title: "Later", day: today)
        store.setReminder(later, ReminderTime(day: today, minutes: 18 * 60))
        let sooner = try store.createTask(title: "Sooner", day: today)
        store.setReminder(sooner, ReminderTime(day: today, minutes: 10 * 60))
        let past = try store.createTask(title: "Past", day: today)
        store.setReminder(past, ReminderTime(day: today, minutes: 7 * 60))
        let done = try store.createTask(title: "Done", day: today)
        store.setReminder(done, ReminderTime(day: today, minutes: 12 * 60))
        store.setCompleted(done, true)
        let plan = ReminderScheduler.plan(tasks: store.allTasks(includingSubtasks: true), now: TestCalendar.date(2026, 10, 30, 9),
                                          calendar: TestCalendar.london)
        #expect(plan.map(\.title) == ["Sooner", "Later"])
    }

    @Test("Subtasks live under their parent and go to Recently Deleted with it")
    func subtasks() throws {
        let parent = try store.createTask(title: "Pack", day: today)
        try store.addSubtask(title: "Passport", to: parent)
        let charger = try store.addSubtask(title: "Charger", to: parent)
        store.setCompleted(charger, true)
        #expect(store.subtasks(of: parent).map(\.title) == ["Passport", "Charger"])
        #expect(store.subtaskProgress(of: parent).map { [$0.done, $0.total] } == [1, 2])
        #expect(store.tasks(on: today).map(\.title) == ["Pack"], "subtasks don't show as tasks of their own")
        #expect(store.allTasks().map(\.title) == ["Pack"])
        store.trash(parent)
        #expect(store.subtasks(of: parent).isEmpty)
        #expect(store.trashedTasks().map(\.title) == ["Pack"])
        store.restoreFromTrash(parent)
        #expect(store.subtasks(of: parent).count == 2)
    }
}
