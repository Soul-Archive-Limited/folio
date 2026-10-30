import SwiftUI

/// 4×3 month capsules; a dot marks months that have entries.
struct MonthCapsuleGrid: View {
    let year: Int
    let current: MonthKey
    let monthsWithEntries: Set<Int>
    let onSelect: (MonthKey) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 4), spacing: Spacing.s) {
            ForEach(1...12, id: \.self) { month in
                let key = MonthKey(year: year, month: month)
                let isCurrent = key == current
                Button { onSelect(key) } label: {
                    VStack(spacing: 3) {
                        Text(key.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.abbreviated)))
                            .folioFont(.headline)
                        Circle()
                            .fill(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.ember))
                            .frame(width: 5, height: 5)
                            .opacity(monthsWithEntries.contains(month) ? 1 : 0)
                    }
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
                    .frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget)
                    .folioGlass(in: .capsule, interactive: true, solidFill: isCurrent ? .ember : nil)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(key.firstDay.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.wide)))
                .accessibilityValue(monthsWithEntries.contains(month) ? "Has entries" : "")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
    }
}
