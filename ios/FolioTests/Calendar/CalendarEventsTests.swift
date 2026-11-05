import Foundation
import SwiftUI
import Testing
@testable import Folio

@Suite("Apple Calendar events")
struct CalendarEventsTests {
    let calendar = TestCalendar.london

    private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvents.Event {
        CalendarEvents.Event(id: title, title: title, start: start, end: end, isAllDay: allDay, color: .blue)
    }

    @Test("Each day an event touches; midnight ends don't spill; all-day first, then by start")
    func days() {
        let trip = event("Trip", TestCalendar.date(2026, 11, 5, 0, 0), TestCalendar.date(2026, 11, 8, 0, 0), allDay: true)
        let dinner = event("Dinner", TestCalendar.date(2026, 11, 6, 19), TestCalendar.date(2026, 11, 6, 22))
        let breakfast = event("Breakfast", TestCalendar.date(2026, 11, 6, 8), TestCalendar.date(2026, 11, 6, 9))
        let late = event("Late show", TestCalendar.date(2026, 11, 9, 23), TestCalendar.date(2026, 11, 10, 1))
        let days = CalendarEvents.byDay([dinner, trip, breakfast, late], calendar: calendar)
        func titles(_ raw: String) -> [String] { days[DayKey(rawValue: raw)!]?.map(\.title) ?? [] }
        #expect(titles("2026-11-05") == ["Trip"])
        #expect(titles("2026-11-06") == ["Trip", "Breakfast", "Dinner"])
        #expect(titles("2026-11-07") == ["Trip"])
        #expect(titles("2026-11-08").isEmpty)
        #expect(titles("2026-11-09") == ["Late show"] && titles("2026-11-10") == ["Late show"])
    }
}
