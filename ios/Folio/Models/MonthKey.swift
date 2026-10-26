import Foundation

/// A calendar month, used for paging and for caching month markers.
nonisolated struct MonthKey: Hashable, Comparable, Sendable, Identifiable {
    let year: Int
    let month: Int

    var id: Int { year * 12 + (month - 1) }

    init(year: Int, month: Int) {
        let index = year * 12 + (month - 1)
        self.year = index.floorDivided(by: 12)
        self.month = index - self.year * 12 + 1
    }

    var firstDay: DayKey { DayKey(year: year, month: month, day: 1) ?? DayKey(date: .now, calendar: .current) }

    var dayCount: Int {
        DayKey.arithmeticCalendar.range(of: .day, in: .month, for: firstDay.utcDate)?.count ?? 30
    }

    var days: [DayKey] {
        (1...dayCount).compactMap { DayKey(year: year, month: month, day: $0) }
    }

    func adding(months: Int) -> MonthKey {
        MonthKey(year: year, month: month + months)
    }

    /// The 42 days (6 weeks) shown for this month, starting on `firstWeekday` (1 = Sunday).
    func gridDays(firstWeekday: Int) -> [DayKey] {
        let offset = (firstDay.weekday - firstWeekday + 7) % 7
        let start = firstDay.adding(days: -offset)
        return (0..<42).map { start.adding(days: $0) }
    }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool { lhs.id < rhs.id }
}

nonisolated private extension Int {
    func floorDivided(by divisor: Int) -> Int {
        let quotient = self / divisor
        return (self % divisor != 0 && (self < 0) != (divisor < 0)) ? quotient - 1 : quotient
    }
}
