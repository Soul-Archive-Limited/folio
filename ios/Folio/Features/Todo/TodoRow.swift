import SwiftUI

/// A To-do row (SPEC §6.7): 26 pt checkbox in the category colour, title, one line of notes,
/// date/time chip.
struct TodoRow: View {
    let task: TaskItem
    let isTicked: Bool
    let tint: Color
    let today: DayKey
    let calendar: Calendar
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            TaskCheckbox(isOn: isTicked, tint: tint, action: onToggle)
                .padding(.top, -6)
            VStack(alignment: .leading, spacing: 3) {
                StrikeText(text: task.title, isStruck: isTicked)
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes).folioFont(.callout).foregroundStyle(.inkSecondary).lineLimit(1)
                }
                HStack(spacing: Spacing.xs) {
                    TaskDateChip(task: task, today: today, calendar: calendar)
                    TaskExtrasLine(task: task)
                }
            }
            .padding(.vertical, Spacing.xs)
            Spacer(minLength: 0)
        }
        .opacity(task.isCompleted && !isTicked ? 0.5 : (isTicked ? 0.75 : 1))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isTicked ? "Done" : "Not done")
        .accessibilityAction(named: isTicked ? "Mark as not done" : "Mark as done", onToggle)
        .accessibilityIdentifier("todo-row")
    }
}

/// Small marks for a reminder, a repeat and subtask progress ("1/3") (Batch I).
struct TaskExtrasLine: View {
    let task: TaskItem
    @Environment(DiaryStore.self) private var store

    var body: some View {
        let progress = store.subtaskProgress(of: task)
        HStack(spacing: Spacing.xs) {
            if task.remindAt != nil {
                Image(systemName: "bell.fill").accessibilityLabel("Reminder")
            }
            if task.repeatRule != nil {
                Image(systemName: "repeat").accessibilityLabel(Text(RepeatRule.decode(task.repeatRule)?.label ?? ""))
            }
            if let progress {
                Label("\(progress.done)/\(progress.total)", systemImage: "checklist")
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel(Text("\(progress.done) of \(progress.total) subtasks done"))
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.inkSecondary)
    }
}
