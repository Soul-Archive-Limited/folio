import Foundation
import SwiftData

/// Reminders, repeats and subtasks (Batch I, SPEC §6.7–6.8).
extension DiaryStore {
    func setReminder(_ task: TaskItem, _ time: ReminderTime?) {
        task.remindAt = time?.rawValue
        task.markChanged(at: now())
        commit()
    }

    func setRepeat(_ task: TaskItem, _ rule: RepeatRule?) {
        task.repeatRule = rule?.json
        task.markChanged(at: now())
        commit()
    }

    /// Ticking a repeating task adds its next one — same title, notes, category, time, rule,
    /// and a reminder moved by the same number of days — unless that next one already exists
    /// (ticked, unticked and ticked again). Returns the new task.
    @discardableResult
    func addNextOccurrence(of task: TaskItem) -> TaskItem? {
        guard let rule = RepeatRule.decode(task.repeatRule), task.parentID == nil else { return nil }
        let base = task.day ?? today
        let nextDay = rule.next(after: base)
        let nextRaw: String? = nextDay.rawValue
        let title = task.title
        let ruleJSON = task.repeatRule
        let existing = fetch(FetchDescriptor<TaskItem>(predicate: #Predicate {
            $0.dayKey == nextRaw && $0.title == title && $0.repeatRule == ruleJSON && !$0.isTombstone && $0.trashedAt == nil
        }))
        guard existing.isEmpty else { return nil }
        guard let next = try? createTask(title: task.title, notes: task.notes, day: nextDay,
                                         minutesFromMidnight: task.minutesFromMidnight, categoryID: task.categoryID) else { return nil }
        next.repeatRule = task.repeatRule
        if let reminder = ReminderTime(rawValue: task.remindAt) {
            next.remindAt = reminder.adding(days: base.days(to: nextDay)).rawValue
        }
        for sub in subtasks(of: task) {
            if let copy = try? createTask(title: sub.title, day: nextDay) { copy.parentID = next.id }
        }
        next.markChanged(at: now())
        commit()
        return next
    }

    // MARK: Subtasks

    func subtasks(of task: TaskItem) -> [TaskItem] {
        _ = revision
        let id: UUID? = task.id
        return fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.parentID == id && !$0.isTombstone && $0.trashedAt == nil }))
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    @discardableResult
    func addSubtask(title: String, to parent: TaskItem) throws(StoreError) -> TaskItem {
        let sub = try createTask(title: title, day: parent.day)
        sub.parentID = parent.id
        sub.markChanged(at: now())
        commit()
        return sub
    }

    /// Done / not done counts for a parent's chip ("1/3").
    func subtaskProgress(of task: TaskItem) -> (done: Int, total: Int)? {
        let subs = subtasks(of: task)
        guard !subs.isEmpty else { return nil }
        return (subs.count { $0.isCompleted }, subs.count)
    }
}
