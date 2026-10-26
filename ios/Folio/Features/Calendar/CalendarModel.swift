import SwiftUI

/// State for the Calendar tab (SPEC §6.2): selected day, visible month, filter and the
/// grid's collapse progress.
@Observable
final class CalendarModel {
    var selectedDay: DayKey
    /// Bound to the month pager's scroll position.
    var visibleMonthID: MonthKey.ID?
    /// Bound to the week strip's scroll position (the week's first day).
    var visibleWeekID: DayKey?
    /// Category ids; empty means no filter.
    var filter: Set<UUID> = []
    /// 0 = full month grid, 1 = collapsed to the selected week. Tracks the finger.
    var collapseProgress: Double = 0
    var showsJumpSheet = false
    /// One selection haptic per gesture (SPEC §3.7). A tap on another month's day pages the
    /// month too, but that page change must not add a second haptic.
    private(set) var selectionHapticCount = 0
    @ObservationIgnored private var suppressMonthHaptic = false
    /// Bumped when a jump should play the quick fade + scale (SPEC §6.3).
    private(set) var jumpCount = 0
    private(set) var months: [MonthKey]

    static let initialMonthRadius = 240
    static let extendStep = 120

    init(today: DayKey) {
        selectedDay = today
        let current = today.monthKey
        months = (-Self.initialMonthRadius...Self.initialMonthRadius).map { current.adding(months: $0) }
        visibleMonthID = current.id
        visibleWeekID = nil
    }

    var visibleMonth: MonthKey {
        visibleMonthID.map { MonthKey(year: 0, month: $0 + 1) } ?? selectedDay.monthKey
    }

    var isCollapsed: Bool { collapseProgress >= 0.999 }
    var isFiltering: Bool { !filter.isEmpty }

    /// Selects a day; days outside the visible month page to their month.
    func select(_ day: DayKey, reduceMotion: Bool) {
        selectedDay = day
        selectionHapticCount += 1
        if day.monthKey != visibleMonth {
            suppressMonthHaptic = true
            withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { visibleMonthID = day.monthKey.id }
        }
    }

    /// Called when the pager settles on a month: keep the selection inside it.
    func monthDidChange(to month: MonthKey) {
        extendIfNeeded(around: month)
        if suppressMonthHaptic { suppressMonthHaptic = false } else { selectionHapticCount += 1 }
        guard selectedDay.monthKey != month else { return }
        let day = min(selectedDay.day, month.dayCount)
        selectedDay = DayKey(year: month.year, month: month.month, day: day) ?? month.firstDay
    }

    /// Called when the collapsed week strip settles on a new week.
    func weekDidChange(to weekStart: DayKey) {
        selectionHapticCount += 1
        let offset = (selectedDay.weekday - weekStart.weekday + 7) % 7
        selectedDay = weekStart.adding(days: offset)
        if selectedDay.monthKey != visibleMonth { visibleMonthID = selectedDay.monthKey.id }
    }

    func goToToday(_ today: DayKey, reduceMotion: Bool) {
        if abs(today.monthKey.id - visibleMonth.id) > 1 {
            jump(to: today.monthKey, selecting: today)
        } else {
            select(today, reduceMotion: reduceMotion)
            withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { visibleMonthID = today.monthKey.id }
        }
    }

    /// Jumps without scrolling through every month in between.
    func jump(to month: MonthKey, selecting day: DayKey? = nil) {
        ensureContains(month)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        suppressMonthHaptic = month != visibleMonth
        selectionHapticCount += 1
        withTransaction(transaction) {
            visibleMonthID = month.id
            selectedDay = day ?? (month == selectedDay.monthKey ? selectedDay : month.firstDay)
        }
        jumpCount += 1
    }

    /// A far jump (the Jump sheet reaches back to 1900) re-centres the list on the target
    /// instead of growing it by thousands of months.
    func ensureContains(_ month: MonthKey) {
        guard let first = months.first, let last = months.last else { return }
        if month < first || month > last {
            months = (-Self.initialMonthRadius...Self.initialMonthRadius).map { month.adding(months: $0) }
        } else {
            extendIfNeeded(around: month)
        }
    }

    /// Keeps the month list "endless": grows it when the pager nears either end.
    func extendIfNeeded(around month: MonthKey) {
        guard let first = months.first, let last = months.last else { return }
        if month.id - first.id < 12 {
            months.insert(contentsOf: (1...Self.extendStep).reversed().map { first.adding(months: -$0) }, at: 0)
        }
        if last.id - month.id < 12 {
            months.append(contentsOf: (1...Self.extendStep).map { last.adding(months: $0) })
        }
    }

    /// Whether a day's markers stay at full strength under the current filter.
    func matchesFilter(_ marker: DayMarker?) -> Bool {
        guard isFiltering else { return true }
        guard let marker else { return false }
        return !marker.categoryIDs.isDisjoint(with: filter)
    }

    func toggleFilter(_ categoryID: UUID) {
        if filter.contains(categoryID) { filter.remove(categoryID) } else { filter.insert(categoryID) }
    }

    /// The selected day's row in its month grid (0–5).
    func selectedRow(firstWeekday: Int) -> Int {
        let grid = selectedDay.monthKey.gridDays(firstWeekday: firstWeekday)
        return (grid.firstIndex(of: selectedDay) ?? 0) / 7
    }
}
