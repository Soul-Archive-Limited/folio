import SwiftUI

/// One action revealed by swiping a card (outside a `List`, where `.swipeActions` isn't
/// available).
struct CardSwipeAction {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let perform: () -> Void
}

extension View {
    /// Leading and trailing swipe actions for a card, like a `List` row: swipe to reveal the
    /// button, or swipe all the way to run it. Also offered as VoiceOver actions.
    func cardSwipeActions(leading: CardSwipeAction?, trailing: CardSwipeAction?, cornerRadius: Double = Radius.card) -> some View {
        modifier(CardSwipeActionsModifier(leading: leading, trailing: trailing, cornerRadius: cornerRadius))
    }
}

private struct CardSwipeActionsModifier: ViewModifier {
    let leading: CardSwipeAction?
    let trailing: CardSwipeAction?
    let cornerRadius: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: Double = 0
    @State private var width: Double = 0
    @State private var fireCount = 0

    static let buttonWidth: Double = 84

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .overlay {
                // While open, a tap on the card closes it instead of opening the entry.
                if offset != 0 {
                    Color.clear.contentShape(.rect).onTapGesture { settle(0) }
                        .offset(x: offset)
                }
            }
            .background(alignment: .leading) { if offset > 0, let leading { button(leading, side: .leading) } }
            .background(alignment: .trailing) { if offset < 0, let trailing { button(trailing, side: .trailing) } }
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            .gesture(HorizontalPanGesture(onChanged: drag, onEnded: end))
            .folioHaptic(.lightImpact, trigger: fireCount)
            .accessibilityActions {
                if let leading { Button(leading.title, action: leading.perform) }
                if let trailing { Button(trailing.title, action: trailing.perform) }
            }
    }

    private func button(_ action: CardSwipeAction, side: HorizontalEdge) -> some View {
        Button {
            settle(0)
            action.perform()
        } label: {
            Label(action.title, systemImage: action.systemImage)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: max(abs(offset) - Spacing.xs, 0))
                .frame(maxHeight: .infinity)
                .background(action.tint, in: .rect(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var fullSwipe: Double { max(width * 0.6, Self.buttonWidth * 2) }

    private func drag(_ translation: Double) {
        var next = translation + (offset == 0 ? 0 : (offset > 0 ? Self.buttonWidth : -Self.buttonWidth))
        if leading == nil { next = min(next, 0) }
        if trailing == nil { next = max(next, 0) }
        offset = next
    }

    private func end(_ translation: Double, _ velocity: Double) {
        if offset <= -fullSwipe, let trailing { return run(trailing) }
        if offset >= fullSwipe, let leading { return run(leading) }
        let projected = offset + velocity * 0.15
        if projected < -Self.buttonWidth / 2, trailing != nil { settle(-Self.buttonWidth) }
        else if projected > Self.buttonWidth / 2, leading != nil { settle(Self.buttonWidth) }
        else { settle(0) }
    }

    private func run(_ action: CardSwipeAction) {
        fireCount += 1
        settle(0)
        action.perform()
    }

    private func settle(_ target: Double) {
        withAnimation(reduceMotion ? FolioMotion.reduced : .snappy) { offset = target }
    }
}
