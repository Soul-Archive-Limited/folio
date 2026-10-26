import Foundation

/// A floating calendar day, stored as `"YYYY-MM-DD"` (SPEC §5).
///
/// A diary day must never move when the phone changes time zone, so days are not `Date`s.
/// All arithmetic uses a fixed proleptic-Gregorian calendar in UTC, which has no daylight
/// saving or time-zone offsets to get wrong. Raw values sort chronologically.
nonisolated struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    /// The fixed calendar all day arithmetic uses.
    static let arithmeticCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month), day >= 1,
              let range = Self.arithmeticCalendar.range(of: .day, in: .month,
                                                       for: Self.utcDate(year: year, month: month, day: 1)),
              range.contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone — e.g. "today" where the phone is now.
    init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    var rawValue: String {
        let y = String(year).leftPadded(to: 4)
        let m = String(month).leftPadded(to: 2)
        let d = String(day).leftPadded(to: 2)
        return "\(y)-\(m)-\(d)"
    }

    var description: String { rawValue }

    var monthKey: MonthKey { MonthKey(year: year, month: month) }

    func adding(days: Int) -> DayKey {
        let date = Self.arithmeticCalendar.date(byAdding: .day, value: days, to: utcDate) ?? utcDate
        return DayKey(date: date, calendar: Self.arithmeticCalendar)
    }

    /// 1 = Sunday … 7 = Saturday.
    var weekday: Int { Self.arithmeticCalendar.component(.weekday, from: utcDate) }

    /// Whole days from `self` to `other` (positive when `other` is later).
    func days(to other: DayKey) -> Int {
        Self.arithmeticCalendar.dateComponents([.day], from: utcDate, to: other.utcDate).day ?? 0
    }

    /// Midnight UTC on this day; for arithmetic and display formatting in UTC only.
    var utcDate: Date { Self.utcDate(year: year, month: month, day: day) }

    /// Midnight on this day in `calendar`'s time zone, e.g. for a `DatePicker`.
    func startDate(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? utcDate
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func utcDate(year: Int, month: Int, day: Int) -> Date {
        arithmeticCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    // Codable as the raw string, matching the encrypted JSON payloads.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid day key"))
        }
        self = key
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
