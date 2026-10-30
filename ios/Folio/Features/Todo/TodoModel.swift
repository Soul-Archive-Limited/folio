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

    /// The active list's groups (Batch I), in order. Each folds; the choice is remembered.
    enum Group: String, CaseIterable, Identifiable {
        case overdue, today, tomorrow, thisWeek, later, noDate

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .overdue: "Overdue"
            case .today: "Today"
            case .tomorrow: "Tomorrow"
            case .thisWeek: "This week"
            case .later: "Later"
            case .noDate: "No date"
            }
        }
    }

    struct Sections {
        var groups: [Group: [TaskItem]] = [:]
        var completed: [TaskItem] = []

        var active: [TaskItem] { Group.allCases.flatMap { groups[$0] ?? [] } }
        var overdue: [TaskItem] { groups[.overdue] ?? [] }
        var undated: [TaskItem] { groups[.noDate] ?? [] }
        /// Groups with tasks, in order.
        var visibleGroups: [Group] { Group.allCases.filter { !(groups[$0] ?? []).isEmpty } }
    }

    /// Only this day's tasks, from the date pill; nil shows everything.
    var dayFilter: DayKey?
    /// Groups the person folded away.
    private(set) var foldedGroups: Set<Group>
    @ObservationIgnored private let defaults: UserDefaults
    static let foldKey = "todoFoldedGroups"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        foldedGroups = Set((defaults.stringArray(forKey: Self.foldKey) ?? []).compactMap(Group.init(rawValue:)))
    }

    func toggleFold(_ group: Group) {
        if foldedGroups.contains(group) { foldedGroups.remove(group) } else { foldedGroups.insert(group) }
        defaults.set(foldedGroups.map(\.rawValue).sorted(), forKey: Self.foldKey)
    }

    /// The group a date falls in: "This week" is the next five days after tomorrow.
    static func group(for dayKey: String?, today: DayKey) -> Group {
        guard let dayKey else { return .noDate }
        let todayRaw = today.rawValue
        if dayKey < todayRaw { return .overdue }
        if dayKey == todayRaw { return .today }
        if dayKey == today.adding(days: 1).rawValue { return .tomorrow }
        if dayKey <= today.adding(days: 6).rawValue { return .thisWeek }
        return .later
    }

    /// Active tasks grouped by date, each group by date, then time, then drag order.
    /// Completed: most recently completed first. Pending ticks stay in Active.
    func sections(from tasks: [TaskItem], today: DayKey) -> Sections {
        var result = Sections()
        for task in tasks where matches(task) {
            if let dayFilter, task.dayKey != dayFilter.rawValue { continue }
            if task.isCompleted && !pending.contains(task.id) {
                result.completed.append(task)
            } else {
                result.groups[Self.group(for: task.dayKey, today: today), default: []].append(task)
            }
        }
        for group in Group.allCases {
            result.groups[group]?.sort(by: Self.listOrder)
        }
        result.completed.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return result
    }

    /// Date, then time (timed tasks first), then the order the person dragged them into.
    static func listOrder(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.dayKey != b.dayKey { return (a.dayKey ?? "") < (b.dayKey ?? "") }
        if a.minutesFromMidnight != b.minutesFromMidnight {
            return (a.minutesFromMidnight ?? .max) < (b.minutesFromMidnight ?? .max)
        }
        return a.sortIndex < b.sortIndex
    }

    /// A drag inside a group. Tasks only move among tasks of their own date (and, for timed
    /// tasks, their own time): returns the date's tasks in their new order, or nil when the
    /// drop would cross into another date.
    static func reorder(_ group: [TaskItem], from source: IndexSet, to destination: Int) -> [TaskItem]? {
        guard let moving = source.first, source.count == 1, group.indices.contains(moving) else { return nil }
        var moved = group
        moved.move(fromOffsets: source, toOffset: destination)
        let task = group[moving]
        let sameSlot = { (other: TaskItem) in other.dayKey == task.dayKey && other.minutesFromMidnight == task.minutesFromMidnight }
        // The moved task must land inside its own run of same-date, same-time tasks.
        guard let newIndex = moved.firstIndex(where: { $0.id == task.id }) else { return nil }
        let before = newIndex > 0 ? moved[newIndex - 1] : nil
        let after = newIndex + 1 < moved.count ? moved[newIndex + 1] : nil
        let fits = (before.map(sameSlot) ?? false) || (after.map(sameSlot) ?? false)
        guard fits, before.map({ sameSlot($0) || listOrder($0, task) }) ?? true,
              after.map({ sameSlot($0) || listOrder(task, $0) }) ?? true else { return nil }
        return moved.filter(sameSlot)
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
