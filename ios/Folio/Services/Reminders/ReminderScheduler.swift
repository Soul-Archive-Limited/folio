import Foundation
import os
import UserNotifications

/// Task reminders (Batch I, SPEC §6.8): local notifications only, nothing through the server.
/// Every device schedules its own from the synced `remindAt`, in its own time zone, so a
/// reminder follows the task to your other iPhones and moves with you when you travel.
/// Actions on the notification: Done, Snooze 1 hour, Tomorrow.
@MainActor
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()

    static let category = "folio.task"
    static let done = "folio.task.done"
    static let snoozeHour = "folio.task.snooze1h"
    static let snoozeTomorrow = "folio.task.tomorrow"
    nonisolated static let prefix = "task-"
    /// iOS keeps at most 64 pending requests per app; leave room.
    static let limit = 60

    weak var store: DiaryStore?
    private var pending: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.devilsense.folio", category: "reminders")

    func start(store: DiaryStore) {
        self.store = store
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: Self.done, title: String(localized: "Done"), options: []),
            UNNotificationAction(identifier: Self.snoozeHour, title: String(localized: "Snooze 1 hour"), options: []),
            UNNotificationAction(identifier: Self.snoozeTomorrow, title: String(localized: "Tomorrow"), options: []),
        ]
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: actions, intentIdentifiers: [])])
        reschedule()
    }

    /// Debounced: called after every change to the diary and on foreground.
    func reschedule() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.reconcile()
        }
    }

    /// The upcoming reminders that should be pending now, nearest first.
    static func plan(tasks: [TaskItem], now: Date, calendar: Calendar) -> [(id: UUID, title: String, body: String?, date: Date)] {
        tasks.compactMap { task -> (UUID, String, String?, Date)? in
            guard !task.isCompleted, task.trashedAt == nil, !task.isTombstone,
                  let time = ReminderTime(rawValue: task.remindAt), let date = time.date(in: calendar), date > now else { return nil }
            return (task.id, task.title, task.notes, date)
        }
        .sorted { $0.3 < $1.3 }
        .prefix(limit)
        .map { (id: $0.0, title: $0.1, body: $0.2, date: $0.3) }
    }

    private func reconcile() async {
        guard let store else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let wanted = Self.plan(tasks: store.allTasks(includingSubtasks: true), now: AppClock.now, calendar: .current)
        let existing = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)
        for item in wanted {
            let content = UNMutableNotificationContent()
            content.title = item.title
            if let body = item.body, !body.isEmpty { content.body = body }
            content.sound = .default
            content.categoryIdentifier = Self.category
            content.threadIdentifier = "folio.tasks"
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let request = UNNotificationRequest(identifier: Self.prefix + item.id.uuidString,
                                                content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            do { try await center.add(request) } catch {
                logger.error("Reminder not scheduled: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }

    // MARK: Permission

    enum Access { case granted, needsPrompt, denied }

    func access() async -> Access {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .notDetermined: .needsPrompt
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { reschedule() }
        return granted
    }

    // MARK: Delegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        let action = response.actionIdentifier
        guard identifier.hasPrefix(Self.prefix), let id = UUID(uuidString: String(identifier.dropFirst(Self.prefix.count))) else { return }
        await MainActor.run { self.handle(action: action, taskID: id) }
    }

    /// Done ticks the task (a repeating one adds its next); snoozes move the reminder, which
    /// syncs, so your other devices follow.
    func handle(action: String, taskID: UUID) {
        guard let store, let task = store.task(id: taskID) else { return }
        switch action {
        case Self.done:
            store.setCompleted(task, true)
        case Self.snoozeHour:
            store.setReminder(task, ReminderTime(date: AppClock.now.addingTimeInterval(3600), calendar: .current))
        case Self.snoozeTomorrow:
            let base = ReminderTime(rawValue: task.remindAt) ?? ReminderTime(date: AppClock.now, calendar: .current)
            store.setReminder(task, ReminderTime(day: DayKey(date: AppClock.now, calendar: .current).adding(days: 1), minutes: base.minutes))
        default:
            break
        }
        reschedule()
    }
}
