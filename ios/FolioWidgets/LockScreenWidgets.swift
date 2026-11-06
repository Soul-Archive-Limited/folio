import SwiftUI
import WidgetKit

/// Lock Screen: the next task, or counts only — the default (Batch J). Titles appear only with
/// "Show details on the Lock Screen" on, and even then are privacy-sensitive.
struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FolioNextTask", provider: SnapshotProvider()) { entry in
            NextTaskView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(FolioRoute.today.url)
        }
        .configurationDisplayName("Next Task")
        .description("Your next task, or how many are left today.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

struct NextTaskView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let next = entry.tasks.first { !$0.isDone }
        let showsTitle = entry.lockDetails && entry.snapshot?.showsDetails == true && next != nil
        switch family {
        case .accessoryInline:
            if showsTitle, let next {
                Label(next.title, image: "folio.todo").privacySensitive()
            } else {
                Label(entry.openCount == 0 ? String(localized: "All clear") : String(localized: "\(entry.openCount) to do today"), image: "folio.todo")
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Label("Folio", image: "folio.journal")
                    .font(.caption2.weight(.semibold))
                    .widgetAccentable()
                if showsTitle, let next {
                    Text(next.title).font(.headline).lineLimit(2).privacySensitive()
                    if let time = next.timeText { Text(time).font(.caption) }
                } else {
                    Text(entry.openCount == 0 ? String(localized: "All clear") : (entry.openCount == 1 ? String(localized: "1 task to do") : String(localized: "\(entry.openCount) tasks to do")))
                        .font(.headline)
                    Text(entry.pagesToday == 0 ? String(localized: "No pages yet today") : (entry.pagesToday == 1 ? String(localized: "1 page today") : String(localized: "\(entry.pagesToday) pages today")))
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TodayCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FolioTodayCount", provider: SnapshotProvider()) { entry in
            TodayCountView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(FolioRoute.today.url)
        }
        .configurationDisplayName("Today's Count")
        .description("Tasks done today out of all of them.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct TodayCountView: View {
    let entry: SnapshotEntry

    var body: some View {
        let total = entry.openCount + entry.doneToday
        Gauge(value: Double(entry.doneToday), in: 0...Double(max(total, 1))) {
            Image("folio.todo")
        } currentValueLabel: {
            Text("\(entry.openCount)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel(entry.openCount == 1 ? String(localized: "1 task left today") : String(localized: "\(entry.openCount) tasks left today"))
    }
}
