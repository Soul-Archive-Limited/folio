import SwiftUI

/// Colour dot, symbol, name and usage count.
struct CategoryManagerRow: View {
    let category: Category
    let usage: CategoryUsage

    var body: some View {
        HStack(spacing: Spacing.s) {
            Circle().fill(category.color.color).frame(width: 14, height: 14)
            Image(systemName: category.symbol ?? "tag")
                .frame(width: 24)
                .foregroundStyle(.inkSecondary)
                .accessibilityHidden(true)
            Text(category.name).folioFont(.body).foregroundStyle(.ink)
            Spacer()
            Text("\(usage.entries + usage.tasks)")
                .folioFont(.callout)
                .monospacedDigit()
                .foregroundStyle(.inkTertiary)
                .accessibilityLabel("^[\(usage.entries + usage.tasks) item](inflect: true)")
        }
        .frame(minHeight: Spacing.minHitTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit category")
    }
}
