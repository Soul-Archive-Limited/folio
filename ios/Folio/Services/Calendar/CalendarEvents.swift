import EventKit
import SwiftUI
import UIKit

/// Apple Calendar events beside the diary (Batch J): opt-in, read-only, on this device only.
/// Events are read from EventKit when shown and kept in memory — never stored in Folio's
/// diary, the widgets' snapshot or anything that syncs.
@Observable
final class CalendarEvents {
    nonisolated struct Event: Identifiable, Equatable, Sendable {
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

    #if DEBUG
    /// `-FolioSeedEvents YES` (with calendar access): two events today and one tomorrow, for screenshots.
    func seedForScreenshots() {
        guard UserDefaults.standard.bool(forKey: "FolioSeedEvents"), hasAccess, let target = store.defaultCalendarForNewEvents else { return }
        let start = Calendar.current.startOfDay(for: .now)
        for (title, hour, length, days) in [("Standup", 9.5, 0.5, 0), ("Dinner with Ana", 19.0, 2.0, 0), ("Dentist", 11.0, 1.0, 1)] {
            let event = EKEvent(eventStore: store)
            event.title = title
            event.calendar = target
            event.startDate = start.addingTimeInterval(Double(days) * 86_400 + hour * 3600)
            event.endDate = event.startDate.addingTimeInterval(length * 3600)
            try? store.save(event, span: .thisEvent)
        }
        invalidate()
    }
    #endif

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

    /// Every day each event touches (one ending at midnight doesn't touch the next day),
    /// all-day first, then by start.
    nonisolated static func byDay(_ events: [Event], calendar: Calendar) -> [DayKey: [Event]] {
        var byDay: [DayKey: [Event]] = [:]
        for item in events {
            var day = DayKey(date: item.start, calendar: calendar)
            let lastDay = DayKey(date: max(item.start, item.end.addingTimeInterval(-1)), calendar: calendar)
            while day <= lastDay {
                byDay[day, default: []].append(item)
                day = day.adding(days: 1)
            }
        }
        return byDay.mapValues { $0.sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) } }
    }

    /// A six-week window around the month, fetched once and cached until the store changes.
    private func events(around month: MonthKey, calendar: Calendar) -> [DayKey: [Event]] {
        let key = "\(month.year)-\(month.month)"
        if let cached = cache[key] { return cached }
        let first = month.firstDay.adding(days: -7).startDate(in: calendar)
        let last = month.firstDay.adding(days: 45).startDate(in: calendar)
        let predicate = store.predicateForEvents(withStart: first, end: last, calendars: nil)
        let items = store.events(matching: predicate).map { event in
            Event(id: event.calendarItemIdentifier + "\(event.startDate.timeIntervalSince1970)",
                  title: event.title ?? String(localized: "Event"), start: event.startDate, end: event.endDate,
                  isAllDay: event.isAllDay, color: Color(cgColor: event.calendar.cgColor))
        }
        let byDay = Self.byDay(items, calendar: calendar)
        cache[key] = byDay
        return byDay
    }
}
