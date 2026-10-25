import SwiftUI

/// A capsule chip, e.g. a category filter (SPEC §3.4, §6.6). Selected chips fill with the
/// category colour and show a checkmark, so state never relies on colour alone (SPEC §3.9).
struct Chip: View {
    let title: String
    var systemImage: String?
    var category: CategoryColor?
    var isSelected = false
    let action: () -> Void

    @Environment(\.self) private var environment

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs - 2) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                } else if let category {
                    Circle().fill(category.color).frame(width: 8, height: 8)
                }
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.semibold))
                }
                Text(title).folioFont(.caption)
            }
            .foregroundStyle(isSelected ? ContrastLabel.color(on: fill, in: environment) : .ink)
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: Spacing.minHitTarget - 12)
            .folioGlass(in: .capsule, interactive: true, solidFill: isSelected ? fill : nil)
            .contentShape(.capsule)
            .padding(.vertical, 6)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .folioHaptic(.lightImpact, trigger: isSelected)
    }

    private var fill: Color { category?.color ?? .ember }
}

#Preview {
    HStack {
        Chip(title: "Travel", category: .ocean, isSelected: true) {}
        Chip(title: "Work", category: .graphite) {}
        Chip(title: "All", systemImage: "line.3.horizontal.decrease") {}
    }
    .padding()
    .background(AuraBackground())
}
