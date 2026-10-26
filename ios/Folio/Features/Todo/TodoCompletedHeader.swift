import SwiftUI

/// "Completed · 12", tap to collapse or expand (state persisted, SPEC §6.7).
struct TodoCompletedHeader: View {
    let count: Int
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { isExpanded.toggle() }
        } label: {
            HStack {
                Text("Completed · \(count)")
                    .folioFont(.caption)
                    .foregroundStyle(.inkSecondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.inkTertiary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .contentShape(.rect)
            .frame(minHeight: Spacing.minHitTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Completed, \(count)")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityAddTraits(.isHeader)
    }
}
