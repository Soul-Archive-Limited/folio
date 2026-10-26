import SwiftUI

/// A task in the day panel. Ticking toggles in place; done tasks stay, checked, struck
/// through and at 50 % (SPEC §6.2).
struct DayTaskRow: View {
    let task: TaskItem
    let tint: Color
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            TaskCheckbox(isOn: task.isCompleted, tint: tint, action: onToggle)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .folioFont(.body)
                    .foregroundStyle(.ink)
                    .strikethrough(task.isCompleted, color: .inkSecondary)
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes).folioFont(.callout).foregroundStyle(.inkSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .opacity(task.isCompleted ? 0.5 : 1)
        .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: task.isCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityValue(task.isCompleted ? "Done" : "Not done")
        .accessibilityAction(named: task.isCompleted ? "Mark as not done" : "Mark as done", onToggle)
    }
}
