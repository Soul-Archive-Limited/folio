import Foundation
import UserNotifications

/// The opt-in morning note "On this day in 2025…" (Batch J). Local notifications only, set on
/// this device for the next week's days that have pages from earlier years. The text names
/// only the year — never a title or words from the diary, since it can show on the Lock Screen.
@MainActor
final class OnThisDayNotifier {
    static let shared = OnThisDayNotifier()
    nonisolated static let prefix = "onthisday-"
    static let enabledKey = "onThisDayNotify"
    static let minutesKey = "onThisDayMinutes"
    /// Seven days ahead; reminders keep the rest of iOS's 64 (ReminderScheduler.limit).
    static let daysAhead = 7

    private weak var store: DiaryStore?
    private var pending: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var minutes: Int { UserDefaults.standard.object(forKey: Self.minutesKey) as? Int ?? 8 * 60 }

    func start(store: DiaryStore) {
        self.store = store
        reschedule()
    }

    func reschedule() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await reconcile()
        }
    }

    /// The days and years to announce, from `now` on.
    static func plan(store: DiaryStore, now: Date, minutes: Int, calendar: Calendar) -> [(day: DayKey, year: Int, date: Date)] {
        let today = DayKey(date: now, calendar: calendar)
        return (0...daysAhead).compactMap { offset in
            let day = today.adding(days: offset)
            guard let date = calendar.date(byAdding: .minute, value: minutes, to: day.startDate(in: calendar)), date > now else { return nil }
            let years = store.entriesOnSameDay(as: day, excluding: UUID()).compactMap(\.day?.year).filter { $0 < day.year }
            guard let year = years.max() else { return nil }
            return (day, year, date)
        }
    }

    private func reconcile() async {
        let existing = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)
        guard isEnabled, let store, await center.notificationSettings().authorizationStatus == .authorized else { return }
        let calendar = Calendar.current
        for item in Self.plan(store: store, now: AppClock.now, minutes: minutes, calendar: calendar) {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "On this day")
            content.body = String(localized: "In \(String(item.year)), you wrote something. Take a look back?")
            content.sound = nil
            content.threadIdentifier = "onthisday"
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let request = UNNotificationRequest(identifier: Self.prefix + item.day.rawValue, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }
}
