import SwiftUI

/// The floating 56 pt Liquid Glass "+" (SPEC §2): tap for a new entry; long-press for
/// New entry / New task / Dictate. It sits bottom-trailing, above the tab bar.
struct FloatingAddButton: View {
    let day: DayKey
    let namespace: Namespace.ID
    let onRequest: (NewItemRequest) -> Void

    /// The composer sheet zooms out of the button (SPEC §2: "+" morphs into the composer).
    static let transitionID = "composer"

    @Namespace private var glass

    var body: some View {
        GlassEffectContainer {
            Menu {
                Button("New entry", systemImage: "square.and.pencil") { onRequest(.entry(day)) }
                Button("New task", systemImage: "checklist") { onRequest(.task(day)) }
                Button("Dictate", systemImage: "mic") { onRequest(.dictation(day)) }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: FloatingButtonMetrics.diameter, height: FloatingButtonMetrics.diameter)
                    .glassEffect(.regular.tint(.ember).interactive(), in: .circle)
                    .glassEffectID("add", in: glass)
            } primaryAction: {
                onRequest(.entry(day))
            }
            .accessibilityLabel("New entry")
            .accessibilityHint("Touch and hold for more options")
            .accessibilityInputLabels(["New entry", "Plus", "Add"])
            .matchedTransitionSource(id: Self.transitionID, in: namespace)
        }
        .padding(.trailing, Spacing.sideMargin)
        .padding(.bottom, Spacing.m)
    }
}

extension View {
    /// Places the floating "+" over this tab's content, above the tab bar.
    func floatingAddButton(day: DayKey, namespace: Namespace.ID, onRequest: @escaping (NewItemRequest) -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            FloatingAddButton(day: day, namespace: namespace, onRequest: onRequest)
        }
    }
}
