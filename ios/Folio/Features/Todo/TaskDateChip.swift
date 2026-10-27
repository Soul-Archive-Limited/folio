import SwiftUI

/// Date (and time) of a task, e.g. "Today 14:30", "Tomorrow", "Mon 3 Nov". Overdue tasks
/// get an ember chip (SPEC §6.7).
struct TaskDateChip: View {
    let task: TaskItem
    let today: DayKey
    let calendar: Calendar

    var body: some View {
        if let day = task.day {
            let overdue = day < today && !task.isCompleted
            HStack(spacing: 3) {
                if overdue { Image(systemName: "clock.badge.exclamationmark").accessibilityHidden(true) }
                Text(label(day))
            }
            .folioFont(.caption)
            .foregroundStyle(overdue ? AnyShapeStyle(.white) : AnyShapeStyle(.inkSecondary))
            .padding(.horizontal, overdue ? Spacing.xs : 0)
            .padding(.vertical, overdue ? 2 : 0)
            .background(overdue ? AnyShapeStyle(.emberStrong) : AnyShapeStyle(.clear), in: .capsule)
            .accessibilityLabel(overdue ? "Overdue, \(label(day))" : label(day))
        }
    }

    private func label(_ day: DayKey) -> String {
        var text = switch today.days(to: day) {
        case 0: String(localized: "Today")
        case 1: String(localized: "Tomorrow")
        case -1: String(localized: "Yesterday")
        default: day.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated)
            .year(day.year == today.year ? .omitted : .defaultDigits))
        }
        if let minutes = task.minutesFromMidnight,
           let time = calendar.date(byAdding: .minute, value: minutes, to: day.startDate(in: calendar)) {
            text += " " + time.formatted(.dateTime.hour().minute())
        }
        return text
    }
}
