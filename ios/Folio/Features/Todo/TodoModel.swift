import SwiftUI

/// The To-do list's state (SPEC §6.7), including the 1.2 s pause between ticking a task and
/// moving it to Completed.
@Observable
final class TodoModel {
    /// Category filter; empty means all.
    var filter: Set<UUID> = []
    /// Ticked but not yet moved to Completed.
    private(set) var pending: Set<UUID> = []
    @ObservationIgnored private var timers: [UUID: Task<Void, Never>] = [:]

    static let pauseBeforeMoving: Duration = .milliseconds(1200)

    struct Sections {
        var overdue: [TaskItem] = []
        var dated: [TaskItem] = []
        var undated: [TaskItem] = []
        var completed: [TaskItem] = []

        var active: [TaskItem] { overdue + dated + undated }
    }

    /// Active: overdue first, then dated ascending, then undated by drag order.
    /// Completed: most recently completed first. Pending ticks stay in Active.
    func sections(from tasks: [TaskItem], today: DayKey) -> Sections {
        var result = Sections()
        let todayRaw = today.rawValue
        for task in tasks where matches(task) {
            if task.isCompleted && !pending.contains(task.id) {
                result.completed.append(task)
            } else if let day = task.dayKey {
                if day < todayRaw { result.overdue.append(task) } else { result.dated.append(task) }
            } else {
                result.undated.append(task)
            }
        }
        let byDate: (TaskItem, TaskItem) -> Bool = { a, b in
            if a.dayKey != b.dayKey { return (a.dayKey ?? "") < (b.dayKey ?? "") }
            if a.minutesFromMidnight != b.minutesFromMidnight {
                return (a.minutesFromMidnight ?? .max) < (b.minutesFromMidnight ?? .max)
            }
            return a.sortIndex < b.sortIndex
        }
        result.overdue.sort(by: byDate)
        result.dated.sort(by: byDate)
        result.undated.sort { $0.sortIndex < $1.sortIndex }
        result.completed.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return result
    }

    func matches(_ task: TaskItem) -> Bool {
        filter.isEmpty || task.categoryID.map(filter.contains) == true
    }

    func isTicked(_ task: TaskItem) -> Bool {
        task.isCompleted || pending.contains(task.id)
    }

    /// Tick in Active: shows as done at once, moves after 1.2 s. Tapping again during the pause
    /// cancels. Ticking a pending task's box again, or unticking in Completed, is instant.
    /// Returns true when this tap ticked the task (so the caller shows the Undo toast).
    @discardableResult
    func toggle(_ task: TaskItem, store: DiaryStore) -> Bool {
        if pending.contains(task.id) {
            timers[task.id]?.cancel()
            timers[task.id] = nil
            pending.remove(task.id)
            if task.isCompleted { store.setCompleted(task, false) }
            return false
        }
        if task.isCompleted {
            store.setCompleted(task, false)
            return false
        }
        pending.insert(task.id)
        store.setCompleted(task, true)
        timers[task.id] = Task { [weak self] in
            try? await Task.sleep(for: Self.pauseBeforeMoving)
            guard !Task.isCancelled, let self else { return }
            withAnimation(FolioMotion.standard()) { _ = self.pending.remove(task.id) }
            self.timers[task.id] = nil
        }
        return true
    }

    /// Undo from the toast: cancels a pending tick, or brings a moved task back to Active.
    func undo(_ task: TaskItem, store: DiaryStore) {
        if pending.contains(task.id) {
            toggle(task, store: store)
        } else if task.isCompleted {
            store.setCompleted(task, false)
        }
    }

    func cancelAll() {
        timers.values.forEach { $0.cancel() }
        timers.removeAll()
        pending.removeAll()
    }
}
