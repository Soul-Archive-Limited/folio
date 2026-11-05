import AppIntents
import SwiftUI
import WidgetKit

/// Today (Batch J): the date, a greeting and the next tasks, each with a tick.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FolioToday", provider: SnapshotProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(FolioRoute.today.url)
        }
        .configurationDisplayName("Today")
        .description("The date, a greeting and your next tasks. Tick them right here.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 4) {
                DateHeader(date: entry.date, large: true)
                Spacer(minLength: 0)
                Text(entry.greeting)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(WidgetPalette.ink.opacity(0.75))
                    .lineLimit(2)
                CountsLine(entry: entry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    DateHeader(date: entry.date, large: true)
                    Spacer(minLength: 0)
                    Text(entry.greeting)
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(WidgetPalette.ink.opacity(0.75))
                        .lineLimit(2)
                }
                .frame(width: 112, alignment: .leading)
                TaskList(entry: entry, limit: 4)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline) {
                    DateHeader(date: entry.date, large: true)
                    Spacer()
                    CountsLine(entry: entry)
                }
                Text(entry.greeting)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(WidgetPalette.ink.opacity(0.8))
                TaskList(entry: entry, limit: 7)
                if let year = entry.onThisDayYear {
                    Link(destination: FolioRoute.onThisDay.url) {
                        Label("On this day in \(String(year)), you wrote something.", systemImage: "clock.arrow.circlepath")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WidgetPalette.ember)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct DateHeader: View {
    let date: Date
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(date, format: .dateTime.weekday(.wide))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(WidgetPalette.ember)
            Text(date, format: .dateTime.day())
                .font(.system(size: large ? 40 : 28, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.ink)
                .widgetAccentable()
        }
        .accessibilityElement(children: .combine)
    }
}

struct CountsLine: View {
    let entry: SnapshotEntry

    var body: some View {
        Text(summary)
            .font(.caption.weight(.medium))
            .foregroundStyle(WidgetPalette.ink.opacity(0.6))
            .lineLimit(1)
    }

    private var summary: String {
        var parts: [String] = []
        if entry.openCount > 0 { parts.append(String(localized: "\(entry.openCount) to do")) }
        if entry.pagesToday > 0 { parts.append(String(localized: "\(entry.pagesToday) pages")) }
        return parts.isEmpty ? String(localized: "A clear day") : parts.joined(separator: " · ")
    }
}

/// Up to `limit` tasks with interactive ticks; counts only when details are off.
struct TaskList: View {
    let entry: SnapshotEntry
    let limit: Int

    var body: some View {
        let tasks = Array(entry.tasks.prefix(limit))
        VStack(alignment: .leading, spacing: 7) {
            if !entry.homeDetails || entry.snapshot?.showsDetails == false {
                Spacer(minLength: 0)
                Text("\(entry.openCount) tasks to do")
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.ink)
                Text("Turn on details in Folio → Profile → Widgets.")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.ink.opacity(0.55))
                Spacer(minLength: 0)
            } else if tasks.isEmpty {
                Spacer(minLength: 0)
                Label("All clear.", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(WidgetPalette.ink.opacity(0.7))
                Spacer(minLength: 0)
            } else {
                ForEach(tasks) { task in TaskRow(task: task, today: entry.dayKey) }
                if entry.tasks.count > limit {
                    Text("+\(entry.tasks.count - limit) more").font(.caption2).foregroundStyle(WidgetPalette.ink.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskRow: View {
    let task: WidgetSnapshot.Task
    let today: String

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleWidgetTaskIntent(taskID: task.id, isDone: !task.isDone)) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(task.isDone ? WidgetPalette.done : (WidgetPalette.tint(light: task.tintLight, dark: task.tintDark) ?? WidgetPalette.ink.opacity(0.55)))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")
            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isDone)
                .foregroundStyle(WidgetPalette.ink.opacity(task.isDone ? 0.45 : 1))
                .lineLimit(1)
                .privacySensitive()
            Spacer(minLength: 4)
            if task.dayKey < today {
                Text("Overdue").font(.caption2.weight(.semibold)).foregroundStyle(WidgetPalette.ember)
            } else if let time = task.timeText {
                Text(time).font(.caption2.monospacedDigit()).foregroundStyle(WidgetPalette.ink.opacity(0.55))
            }
        }
    }
}
