import EventKit
import SwiftUI
import UIKit

/// Apple Calendar events beside the diary (Batch J): opt-in, read-only, on this device only.
/// Events are read from EventKit when shown and kept in memory — never stored in Folio's
/// diary, the widgets' snapshot or anything that syncs.
@Observable
final class CalendarEvents {
    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let color: Color
    }

    static let enabledKey = "showsCalendarEvents"

    private(set) var revision = 0
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var cache: [String: [DayKey: [Event]]] = [:]
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidate() }
        }
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var isShowing: Bool { isEnabled && hasAccess }

    enum Access { case granted, needsPrompt, denied }

    var access: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .needsPrompt
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        invalidate()
        return granted
    }

    func invalidate() {
        cache = [:]
        revision += 1
    }

    /// The day's events, all-day first, then by start.
    func events(on day: DayKey, calendar: Calendar = .current) -> [Event] {
        _ = revision
        guard isShowing else { return [] }
        return events(around: day.monthKey, calendar: calendar)[day] ?? []
    }

    /// Days in the month's grid that have events (the cell mark).
    func days(in month: MonthKey, calendar: Calendar = .current) -> Set<DayKey> {
        _ = revision
        guard isShowing else { return [] }
        return Set(events(around: month, calendar: calendar).keys)
    }

    /// A six-week window around the month, fetched once and cached until the store changes.
    private func events(around month: MonthKey, calendar: Calendar) -> [DayKey: [Event]] {
        let key = "\(month.year)-\(month.month)"
        if let cached = cache[key] { return cached }
        let first = month.firstDay.adding(days: -7).startDate(in: calendar)
        let last = month.firstDay.adding(days: 45).startDate(in: calendar)
        let predicate = store.predicateForEvents(withStart: first, end: last, calendars: nil)
        var byDay: [DayKey: [Event]] = [:]
        for event in store.events(matching: predicate) {
            let item = Event(id: event.calendarItemIdentifier + "\(event.startDate.timeIntervalSince1970)",
                             title: event.title ?? String(localized: "Event"), start: event.startDate, end: event.endDate,
                             isAllDay: event.isAllDay, color: Color(cgColor: event.calendar.cgColor))
            // Every day the event touches (an event ending at midnight doesn't touch the next day).
            var day = DayKey(date: event.startDate, calendar: calendar)
            let lastDay = DayKey(date: max(event.startDate, event.endDate.addingTimeInterval(-1)), calendar: calendar)
            while day <= lastDay {
                byDay[day, default: []].append(item)
                day = day.adding(days: 1)
            }
        }
        for (day, items) in byDay {
            byDay[day] = items.sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
        }
        cache[key] = byDay
        return byDay
    }
}
