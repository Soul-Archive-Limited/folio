import Foundation
import Testing
@testable import Folio

@Suite("DayKey and MonthKey")
struct DayKeyTests {
    @Test("Raw values round-trip and sort chronologically")
    func rawValues() throws {
        let key = try #require(DayKey(rawValue: "2026-03-09"))
        #expect(key.rawValue == "2026-03-09")
        #expect(key.year == 2026 && key.month == 3 && key.day == 9)
        let keys = ["2025-12-31", "2026-01-01", "1999-07-04"].compactMap(DayKey.init(rawValue:))
        #expect(keys.sorted().map(\.rawValue) == ["1999-07-04", "2025-12-31", "2026-01-01"])
        #expect(keys.sorted().map(\.rawValue) == keys.map(\.rawValue).sorted())
    }

    @Test("Invalid days are rejected", arguments: ["2026-02-29", "2026-13-01", "2026-00-10", "2026-4-1", "nonsense", "2026-04-31"])
    func invalid(raw: String) {
        #expect(DayKey(rawValue: raw) == nil)
    }

    @Test("Leap days exist only in leap years")
    func leapDays() {
        #expect(DayKey(rawValue: "2028-02-29") != nil)
        #expect(DayKey(rawValue: "1900-02-29") == nil)
        #expect(DayKey(rawValue: "2000-02-29") != nil)
    }

    @Test("Day arithmetic crosses months, years and DST changes")
    func arithmetic() throws {
        let key = try #require(DayKey(rawValue: "2026-12-31"))
        #expect(key.adding(days: 1).rawValue == "2027-01-01")
        #expect(key.adding(days: -365).rawValue == "2025-12-31")
        let march = try #require(DayKey(rawValue: "2026-03-28"))
        #expect(march.adding(days: 2).rawValue == "2026-03-30")
        #expect(march.days(to: march.adding(days: 40)) == 40)
    }

    @Test("Weekday is correct (1 = Sunday)")
    func weekday() throws {
        #expect(try #require(DayKey(rawValue: "2026-10-25")).weekday == 1)
        #expect(try #require(DayKey(rawValue: "2026-10-31")).weekday == 7)
    }

    @Test("The same instant is a different day in different time zones")
    func todayDependsOnZone() throws {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var tokyo = london
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let instant = try #require(london.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 20)))
        #expect(DayKey(date: instant, calendar: london).rawValue == "2026-10-14")
        #expect(DayKey(date: instant, calendar: tokyo).rawValue == "2026-10-15")
    }

    @Test("Month grid has 42 days and starts on the chosen weekday", arguments: [1, 2, 7])
    func grid(firstWeekday: Int) {
        let grid = MonthKey(year: 2026, month: 10).gridDays(firstWeekday: firstWeekday)
        #expect(grid.count == 42)
        #expect(grid[0].weekday == firstWeekday)
        #expect(grid.contains { $0.rawValue == "2026-10-01" })
        #expect(grid.contains { $0.rawValue == "2026-10-31" })
    }

    @Test("Month keys normalise and step across years")
    func months() {
        #expect(MonthKey(year: 2026, month: 13) == MonthKey(year: 2027, month: 1))
        #expect(MonthKey(year: 2026, month: 0) == MonthKey(year: 2025, month: 12))
        #expect(MonthKey(year: 2026, month: 1).adding(months: -1) == MonthKey(year: 2025, month: 12))
        #expect(MonthKey(year: 2028, month: 2).dayCount == 29)
    }

    @Test("Codable uses the raw string")
    func codable() throws {
        let key = try #require(DayKey(rawValue: "2026-10-14"))
        let json = try JSONEncoder().encode(key)
        #expect(String(decoding: json, as: UTF8.self) == "\"2026-10-14\"")
        #expect(try JSONDecoder().decode(DayKey.self, from: json) == key)
    }
}
