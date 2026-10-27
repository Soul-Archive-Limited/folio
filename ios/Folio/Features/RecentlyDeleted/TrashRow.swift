import SwiftUI

/// A Recently Deleted row: icon, title, original date and days left (SPEC §5.2).
struct TrashRow: View {
    let row: TrashRowData

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: row.systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(row.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(row.title)
                    .folioFont(.headline)
                    .foregroundStyle(.ink)
                    .strikethrough(row.isCompleted, color: .inkTertiary)
                    .lineLimit(2)
                Text(row.detail)
                    .folioFont(.callout)
                    .foregroundStyle(.inkSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: Spacing.xs)
            Text(daysLeft)
                .folioFont(.caption)
                .foregroundStyle(row.daysLeft <= 3 ? .danger : .inkTertiary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: Spacing.minHitTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(row.isCompleted ? Text("Done") : Text(""))
        .accessibilityIdentifier("trash-row")
    }

    private var daysLeft: String {
        row.daysLeft == 0
            ? String(localized: "Under a day left")
            : String(AttributedString(localized: "^[\(row.daysLeft) day](inflect: true) left").characters)
    }
}
