import SwiftUI
import WidgetKit

/// One moment of a widget: the snapshot seen from `date` (today, greeting, tasks for that day).
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let homeDetails: Bool
    let lockDetails: Bool

    var dayKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: date)
        return snapshot?.greetings[WidgetSnapshot.period(hour: hour)] ?? String(localized: "Your days, kept.")
    }

    /// Open tasks from earlier days, then this day's (open first, then done).
    var tasks: [WidgetSnapshot.Task] {
        let day = dayKey
        let all = snapshot?.tasks ?? []
        let overdue = all.filter { $0.dayKey < day && !$0.isDone }
        let today = all.filter { $0.dayKey == day }.sorted { ($0.isDone ? 1 : 0, $0.minutes ?? 9999) < ($1.isDone ? 1 : 0, $1.minutes ?? 9999) }
        return overdue + today
    }

    var openCount: Int { tasks.count { !$0.isDone } }
    var doneToday: Int { tasks.count { $0.isDone && $0.dayKey == dayKey } }
    var pagesToday: Int { month?.days[dayKey]?.entries ?? 0 }

    var month: WidgetSnapshot.Month? {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return snapshot?.months.first { $0.year == parts.year && $0.month == parts.month }
    }

    var onThisDayYear: Int? { snapshot?.onThisDayYears[dayKey] }

    static let sample = SnapshotEntry(date: .now, snapshot: WidgetSnapshot(
        writtenAt: .now,
        greetings: ["morning": "Good morning.", "afternoon": "Good afternoon.", "evening": "Good evening.", "night": "Still up?", "early": "First light."],
        tasks: [], months: [], showsDetails: true), homeDetails: true, lockDetails: false)
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        // The gallery shows the person's own month when Folio has written one.
        let current = entry(at: .now)
        completion(context.isPreview && current.snapshot == nil ? .sample : current)
    }

    /// An entry now, at each greeting change and at midnight for the next day; the app reloads
    /// the timeline whenever the diary changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date.now
        var dates = [now]
        let startOfDay = calendar.startOfDay(for: now)
        for dayOffset in 0...1 {
            for hour in [0] + WidgetSnapshot.periodStarts {
                if let date = calendar.date(byAdding: DateComponents(day: dayOffset, hour: hour), to: startOfDay), date > now {
                    dates.append(date)
                }
            }
        }
        let entries = dates.sorted().prefix(8).map(entry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> SnapshotEntry {
        SnapshotEntry(date: date, snapshot: WidgetSnapshot.load(), homeDetails: AppGroup.showsHomeDetails, lockDetails: AppGroup.showsLockDetails)
    }
}
