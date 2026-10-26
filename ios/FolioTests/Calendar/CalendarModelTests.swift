import Foundation
import Testing
@testable import Folio

@MainActor
@Suite("Calendar model and layout (SPEC §6.2)")
struct CalendarModelTests {
    let today = DayKey(year: 2026, month: 10, day: 27)!

    @Test("Starts on today's month with ±240 months available")
    func initialState() {
        let model = CalendarModel(today: today)
        #expect(model.visibleMonth == today.monthKey)
        #expect(model.selectedDay == today)
        #expect(model.months.count == 481)
        #expect(model.months.first == today.monthKey.adding(months: -240))
    }

    @Test("The month list grows near either edge")
    func extends() {
        let model = CalendarModel(today: today)
        let first = model.months.first!
        model.extendIfNeeded(around: first.adding(months: 3))
        #expect(model.months.first == first.adding(months: -CalendarModel.extendStep))
        let last = model.months.last!
        model.extendIfNeeded(around: last)
        #expect(model.months.last == last.adding(months: CalendarModel.extendStep))
    }

    @Test("Paging to another month keeps the day number, clamped to the month length")
    func monthChangeKeepsDay() {
        let model = CalendarModel(today: DayKey(year: 2026, month: 1, day: 31)!)
        model.monthDidChange(to: MonthKey(year: 2026, month: 2))
        #expect(model.selectedDay.rawValue == "2026-02-28")
        model.monthDidChange(to: MonthKey(year: 2026, month: 3))
        #expect(model.selectedDay.rawValue == "2026-03-28")
    }

    @Test("Selecting an out-of-month day pages to its month")
    func outOfMonthTap() {
        let model = CalendarModel(today: today)
        let november2 = DayKey(year: 2026, month: 11, day: 2)!
        model.select(november2, reduceMotion: true)
        #expect(model.selectedDay == november2)
        #expect(model.visibleMonth == november2.monthKey)
    }

    @Test("Swiping the week strip keeps the same weekday")
    func weekChange() {
        let model = CalendarModel(today: today) // Tuesday
        let nextWeekStart = WeekPager.weekStart(of: today, firstWeekday: 1).adding(days: 7)
        model.weekDidChange(to: nextWeekStart)
        #expect(model.selectedDay.rawValue == "2026-11-03")
        #expect(model.selectedDay.weekday == today.weekday)
        #expect(model.visibleMonth == MonthKey(year: 2026, month: 11))
    }

    @Test("Jumping far away doesn't scroll through months and plays the jump")
    func jump() {
        let model = CalendarModel(today: today)
        model.jump(to: MonthKey(year: 1905, month: 3))
        #expect(model.visibleMonth == MonthKey(year: 1905, month: 3))
        #expect(model.selectedDay.rawValue == "1905-03-01")
        #expect(model.jumpCount == 1)
        #expect(model.months.contains(MonthKey(year: 1905, month: 3)))
    }

    @Test("Today goes back from anywhere")
    func goToToday() {
        let model = CalendarModel(today: today)
        model.jump(to: MonthKey(year: 2020, month: 5))
        model.goToToday(today, reduceMotion: true)
        #expect(model.selectedDay == today && model.visibleMonth == today.monthKey)
    }

    @Test("Filter toggles categories on and off")
    func filter() {
        let model = CalendarModel(today: today)
        let id = UUID()
        model.toggleFilter(id)
        #expect(model.isFiltering)
        model.toggleFilter(id)
        #expect(!model.isFiltering)
    }

    @Test("Selected row is the week containing the selected day", arguments: [(1, 4), (2, 4)])
    func selectedRow(firstWeekday: Int, expected: Int) {
        // October 2026 starts on a Thursday; the 27th is in the fifth row (index 4) for Sunday or Monday starts.
        #expect(CalendarModel(today: today).selectedRow(firstWeekday: firstWeekday) == expected)
    }

    @Test("Layout: 7 cells and 6 gaps fit the panel; collapse distance is grid minus one week")
    func layout() {
        let layout = CalendarLayout(width: 402)
        #expect(abs(layout.cellSize * 7 + CalendarLayout.gap * 6 + CalendarLayout.panelPadding * 2 - layout.panelWidth) < 0.001)
        #expect(abs(layout.gridHeight(progress: 0) - layout.fullGridHeight) < 0.001)
        #expect(abs(layout.gridHeight(progress: 1) - layout.weekHeight) < 0.001)
        #expect(abs(layout.gridHeight(progress: 2) - layout.weekHeight) < 0.001)
        #expect(layout.cellSize >= Spacing.minHitTarget)
    }

    @Test("Day cells read their contents (SPEC §3.9)")
    func accessibilityLabel() {
        let day = DayKey(year: 2026, month: 10, day: 13)!
        let state = DayCellState(day: day, marker: DayMarker(entryCount: 2, doneTaskCount: 1), isToday: false,
                                 isSelected: false, isInMonth: true, matchesFilter: true, showsPhotoTiles: true)
        let label = DayCellAccessibility.label(for: state)
        #expect(label.contains("Tuesday"))
        #expect(label.contains("13"))
        #expect(label.contains("2 entries"))
        #expect(label.contains("1 task done"))
    }
}
