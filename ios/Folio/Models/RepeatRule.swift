import Foundation

/// How a task repeats (Batch I, SPEC §6.8), stored as JSON in `TaskItem.repeatRule` and read the
/// same way by the web app. Completing a repeating task leaves it done on its day and adds the
/// next one.
nonisolated struct RepeatRule: Codable, Equatable, Hashable, Sendable {
    enum Frequency: String, Codable, CaseIterable, Sendable {
        case daily, weekdays, weekly, monthly, yearly, custom
    }

    enum Unit: String, Codable, CaseIterable, Sendable {
        case day, week, month
    }

    var frequency: Frequency
    /// Custom only: every `interval` days, weeks or months.
    var interval: Int = 1
    var unit: Unit = .day

    static func decode(_ json: String?) -> RepeatRule? {
        guard let data = json?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(RepeatRule.self, from: data)
    }

    var json: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The day the next one falls on.
    func next(after day: DayKey) -> DayKey {
        switch frequency {
        case .daily: return day.adding(days: 1)
        case .weekdays:
            var next = day.adding(days: 1)
            while next.weekday == 1 || next.weekday == 7 { next = next.adding(days: 1) }
            return next
        case .weekly: return day.adding(days: 7)
        case .monthly: return Self.adding(months: 1, to: day)
        case .yearly: return Self.adding(months: 12, to: day)
        case .custom:
            let n = max(interval, 1)
            switch unit {
            case .day: return day.adding(days: n)
            case .week: return day.adding(days: 7 * n)
            case .month: return Self.adding(months: n, to: day)
            }
        }
    }

    /// Same day of the month, or the month's last day when it's shorter (31 Jan → 28 Feb).
    static func adding(months: Int, to day: DayKey) -> DayKey {
        let total = day.year * 12 + (day.month - 1) + months
        let year = total / 12, month = total % 12 + 1
        let last = MonthKey(year: year, month: month).dayCount
        return DayKey(year: year, month: month, day: min(day.day, last)) ?? day
    }

    var label: String {
        switch frequency {
        case .daily: String(localized: "Every day")
        case .weekdays: String(localized: "Every weekday")
        case .weekly: String(localized: "Every week")
        case .monthly: String(localized: "Every month")
        case .yearly: String(localized: "Every year")
        case .custom:
            switch unit {
            case .day: interval == 1 ? String(localized: "Every day") : String(localized: "Every \(interval) days")
            case .week: interval == 1 ? String(localized: "Every week") : String(localized: "Every \(interval) weeks")
            case .month: interval == 1 ? String(localized: "Every month") : String(localized: "Every \(interval) months")
            }
        }
    }
}

/// A reminder's floating local time, "YYYY-MM-DDTHH:mm" (`TaskItem.remindAt`). Like a task's
/// day it never moves with the time zone: each device turns it into a moment in its own zone.
nonisolated struct ReminderTime: Equatable, Hashable, Sendable {
    var day: DayKey
    var minutes: Int

    init(day: DayKey, minutes: Int) {
        self.day = day
        self.minutes = min(max(minutes, 0), 24 * 60 - 1)
    }

    init?(rawValue: String?) {
        guard let rawValue, rawValue.count == 16 else { return nil }
        let parts = rawValue.split(separator: "T")
        guard parts.count == 2, let day = DayKey(rawValue: String(parts[0])) else { return nil }
        let time = parts[1].split(separator: ":")
        guard time.count == 2, let h = Int(time[0]), let m = Int(time[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        self.init(day: day, minutes: h * 60 + m)
    }

    var rawValue: String { String(format: "%@T%02d:%02d", day.rawValue, minutes / 60, minutes % 60) }

    /// The moment in `calendar`'s time zone.
    func date(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: minutes / 60, minute: minutes % 60))
    }

    init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(day: DayKey(date: date, calendar: calendar), minutes: (parts.hour ?? 9) * 60 + (parts.minute ?? 0))
    }

    func adding(days: Int) -> ReminderTime { ReminderTime(day: day.adding(days: days), minutes: minutes) }
}
