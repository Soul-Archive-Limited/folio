import Foundation
import Testing
@testable import Folio

/// Tuesday 27 October 2026, 09:30 — the reference "now" for every phrase.
@Suite("Quick add understands natural dates and times (Batch I)")
nonisolated struct QuickAddNaturalTests {
    static let today = DayKey(rawValue: "2026-10-27")!
    static let now = 9 * 60 + 30

    struct Case: CustomTestStringConvertible, Sendable {
        let text: String
        let title: String
        let day: String?
        let time: String?
        var testDescription: String { "\"\(text)\"" }
    }

    static func run(_ text: String, monthFirst: Bool = false) -> QuickAddParser.Result {
        QuickAddParser.parse(text, today: today, minutesNow: now, monthFirst: monthFirst)
    }

    static func hhmm(_ minutes: Int?) -> String? {
        minutes.map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
    }

    /// en-GB and en-IN: day before month.
    static let dayFirst: [Case] = [
        Case(text: "Call Mum today", title: "Call Mum", day: "2026-10-27", time: nil),
        Case(text: "Call Mum tomorrow", title: "Call Mum", day: "2026-10-28", time: nil),
        Case(text: "tomorrow call Mum", title: "call Mum", day: "2026-10-28", time: nil),
        Case(text: "Pay rent tmrw", title: "Pay rent", day: "2026-10-28", time: nil),
        Case(text: "Book flights day after tomorrow", title: "Book flights", day: "2026-10-29", time: nil),
        Case(text: "Dentist in 5 days", title: "Dentist", day: "2026-11-01", time: nil),
        Case(text: "Dentist after 5 days", title: "Dentist", day: "2026-11-01", time: nil),
        Case(text: "Renew insurance in two weeks", title: "Renew insurance", day: "2026-11-10", time: nil),
        Case(text: "Check plants in a week", title: "Check plants", day: "2026-11-03", time: nil),
        Case(text: "Car service in 3 months", title: "Car service", day: "2027-01-27", time: nil),
        Case(text: "Haircut next week", title: "Haircut", day: "2026-11-03", time: nil),
        Case(text: "Pay credit card next month", title: "Pay credit card", day: "2026-11-27", time: nil),
        Case(text: "Clean the bikes this weekend", title: "Clean the bikes", day: "2026-10-31", time: nil),
        Case(text: "Hike weekend", title: "Hike", day: "2026-10-31", time: nil),
        Case(text: "Team lunch next Monday", title: "Team lunch", day: "2026-11-02", time: nil),
        Case(text: "Team lunch on Monday", title: "Team lunch", day: "2026-11-02", time: nil),
        Case(text: "Gym Friday", title: "Gym", day: "2026-10-30", time: nil),
        Case(text: "Gym on fri", title: "Gym", day: "2026-10-30", time: nil),
        Case(text: "Standup next Tuesday", title: "Standup", day: "2026-11-03", time: nil),
        Case(text: "Standup this Tuesday", title: "Standup", day: "2026-10-27", time: nil),
        Case(text: "Pay council tax on 5 Nov", title: "Pay council tax", day: "2026-11-05", time: nil),
        Case(text: "Bonfire 5th November", title: "Bonfire", day: "2026-11-05", time: nil),
        Case(text: "Bonfire on the 5th of November", title: "Bonfire", day: "2026-11-05", time: nil),
        Case(text: "Diwali shopping 8 Nov 2026", title: "Diwali shopping", day: "2026-11-08", time: nil),
        Case(text: "Send card 2 Jan", title: "Send card", day: "2027-01-02", time: nil),
        Case(text: "Visa renewal 15/12", title: "Visa renewal", day: "2026-12-15", time: nil),
        Case(text: "Visa renewal on 15/12/2026", title: "Visa renewal", day: "2026-12-15", time: nil),
        Case(text: "Exam 03-11-26", title: "Exam", day: "2026-11-03", time: nil),
        Case(text: "Exam 3.11.2026", title: "Exam", day: "2026-11-03", time: nil),
        Case(text: "Call Mum tomorrow 6pm", title: "Call Mum", day: "2026-10-28", time: "18:00"),
        Case(text: "Call Mum tomorrow at 6pm", title: "Call Mum", day: "2026-10-28", time: "18:00"),
        Case(text: "Call Mum 6pm tomorrow", title: "Call Mum", day: "2026-10-28", time: "18:00"),
        Case(text: "Dinner at 7", title: "Dinner", day: "2026-10-27", time: "19:00"),
        Case(text: "Run at 10", title: "Run", day: "2026-10-27", time: "10:00"),
        Case(text: "Run at 9", title: "Run", day: "2026-10-27", time: "21:00"),
        Case(text: "Pick up parcel at 18:30", title: "Pick up parcel", day: "2026-10-27", time: "18:30"),
        Case(text: "Pick up parcel 18.30", title: "Pick up parcel", day: "2026-10-27", time: "18:30"),
        Case(text: "Coffee with Ana at 8am", title: "Coffee with Ana", day: "2026-10-28", time: "08:00"),
        Case(text: "Pharmacy 5:15 pm", title: "Pharmacy", day: "2026-10-27", time: "17:15"),
        Case(text: "Lunch with Raj noon", title: "Lunch with Raj", day: "2026-10-27", time: "12:00"),
        Case(text: "Call bank tonight", title: "Call bank", day: "2026-10-27", time: "20:00"),
        Case(text: "Water plants tomorrow morning", title: "Water plants", day: "2026-10-28", time: "09:00"),
        Case(text: "Meeting next Monday at 9", title: "Meeting", day: "2026-11-02", time: "09:00"),
        Case(text: "School pickup Friday at 3", title: "School pickup", day: "2026-10-30", time: "15:00"),
        Case(text: "Call Dad this evening", title: "Call Dad", day: "2026-10-27", time: "18:00"),
    ]

    /// Lines that must stay exactly as typed.
    static let untouched: [String] = [
        "Today's papers", "Read Monday notes", "Buy 2 apples", "Enjoy the sun", "Tomorrow",
        "Look at 3 options carefully", "Room 101",
    ]

    @Test("Day-first phrases (en-GB, en-IN)", arguments: dayFirst)
    func dayFirstPhrases(_ c: Case) {
        let result = Self.run(c.text)
        #expect(result.title == c.title)
        #expect(result.day?.rawValue == c.day)
        #expect(Self.hhmm(result.minutesFromMidnight) == c.time)
    }

    @Test("Lines without a date stay as typed", arguments: untouched)
    func untouchedLines(_ text: String) {
        let result = Self.run(text)
        #expect(result.title == text)
        #expect(result.day == nil)
        #expect(result.minutesFromMidnight == nil)
    }

    @Test("US order reads month first")
    func monthFirst() {
        #expect(Self.run("Visa renewal 12/15", monthFirst: true).day?.rawValue == "2026-12-15")
        #expect(Self.run("Visa renewal 12/15").day == nil, "day-first: there's no 15th month")
    }

    @Test("A time that has passed today means tomorrow")
    func passedTime() {
        let result = Self.run("Alarm check at 8am")
        #expect(result.day?.rawValue == "2026-10-28")
    }

    @Test("Impossible dates are left alone", arguments: ["Party 31 Feb", "Party 30/02", "Tea at 25"])
    func impossible(_ text: String) {
        #expect(Self.run(text).day == nil)
    }

    @Test("Real locales: en-GB and en-IN read day first, en-US month first")
    func realLocales() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 9, minute: 30))!
        for id in ["en_GB", "en_IN"] {
            #expect(QuickAddParser.parse("Fees 4/11", now: now, calendar: calendar, locale: Locale(identifier: id)).day?.rawValue == "2026-11-04")
        }
        // 11 April has passed this year, so month-first means next April.
        #expect(QuickAddParser.parse("Fees 4/11", now: now, calendar: calendar, locale: Locale(identifier: "en_US")).day?.rawValue == "2027-04-11")
    }

    @Test("The chip says what was understood")
    func summary() {
        #expect(Self.run("Call Mum tomorrow 6pm").summary(today: Self.today) == "Tomorrow · 18:00")
        #expect(Self.run("Dinner at 7").summary(today: Self.today) == "Today · 19:00")
        #expect(Self.run("Plain task").summary(today: Self.today) == nil)
    }
}
