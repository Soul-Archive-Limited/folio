import SwiftUI

/// The floating 56 pt Liquid Glass "+" (SPEC §2): tap for a new entry; long-press for
/// New entry / New task / Dictate an entry. It sits bottom-trailing, above the tab bar, on
/// the root screens of Calendar and Journal only; it morphs away on pushed screens.
struct FloatingAddButton: View {
    let day: DayKey
    var isVisible = true
    let namespace: Namespace.ID
    let onRequest: (NewItemRequest) -> Void

    /// The composer sheet zooms out of the button (SPEC §2: "+" morphs into the composer).
    static let transitionID = "composer"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TourModel.self) private var tour: TourModel?
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer {
            if isVisible {
                Menu {
                    Button("New entry", systemImage: "square.and.pencil") { onRequest(.entry(day)) }
                    Button("New task", systemImage: "checklist") { onRequest(.task(day)) }
                    Button("Dictate an entry", systemImage: "mic") { onRequest(.dictation(day)) }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: FloatingButtonMetrics.diameter, height: FloatingButtonMetrics.diameter)
                        .glassEffect(.regular.tint(.ember).interactive(), in: .circle)
                        .glassEffectID("add", in: glass)
                        .glassEffectTransition(reduceMotion ? .identity : .materialize)
                } primaryAction: {
                    onRequest(.entry(day))
                }
                .accessibilityLabel("New entry")
                .accessibilityHint("Touch and hold for more options")
                .accessibilityInputLabels(["New entry", "Plus", "Add"])
                .matchedTransitionSource(id: Self.transitionID, in: namespace)
                .tourTip(AddEntryTip.self, tour, arrowEdge: .bottom)
                .transition(FolioMotion.transition(.scale(scale: 0.4).combined(with: .opacity), reduceMotion: reduceMotion))
            }
        }
        .frame(width: FloatingButtonMetrics.diameter, height: FloatingButtonMetrics.diameter)
        .padding(.trailing, Spacing.sideMargin)
        .padding(.bottom, Spacing.m)
        .animation(reduceMotion ? FolioMotion.reduced : .spring(duration: 0.4, bounce: 0.2), value: isVisible)
    }
}

extension View {
    /// Places the floating "+" over this tab's content, above the tab bar.
    func floatingAddButton(day: DayKey, isVisible: Bool = true, namespace: Namespace.ID,
                           onRequest: @escaping (NewItemRequest) -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            FloatingAddButton(day: day, isVisible: isVisible, namespace: namespace, onRequest: onRequest)
        }
    }
}
