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
                TaskDateChip(task: task, today: today, calendar: calendar)
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
