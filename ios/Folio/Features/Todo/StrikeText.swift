import SwiftUI

/// A task title whose strike-through draws across from the leading edge (SPEC §3.6).
struct StrikeText: View {
    let text: String
    let isStruck: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .folioFont(.body)
            .foregroundStyle(.ink)
            .lineLimit(2)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.inkSecondary)
                    .frame(height: 1.5)
                    .scaleEffect(x: isStruck ? 1 : 0, anchor: .leading)
                    .opacity(isStruck ? 1 : 0)
                    .animation(reduceMotion ? FolioMotion.reduced : .easeOut(duration: 0.25), value: isStruck)
                    .accessibilityHidden(true)
            }
    }
}
