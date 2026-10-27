import SwiftUI

/// The 12 category colours; the selected one shows a checkmark, not just a ring.
struct ColorSwatchGrid: View {
    @Binding var selection: CategoryColor
    @Environment(\.self) private var environment

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 6), spacing: Spacing.s) {
            ForEach(CategoryColor.allCases) { color in
                Button { selection = color } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                        .overlay {
                            if selection == color {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(ContrastLabel.color(on: color.color, in: environment))
                            }
                        }
                        .overlay { Circle().strokeBorder(.ink.opacity(selection == color ? 0.5 : 0), lineWidth: 2).padding(-4) }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(color.displayName))
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
        .folioHaptic(.selection, trigger: selection)
    }
}
