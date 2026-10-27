import SwiftUI

/// The current `ToastCenter` toast, sliding up from the bottom with a spring and leaving the
/// same way; under Reduce Motion it only fades. Place it where the toast should rest.
struct ToastSlot: View {
    let center: ToastCenter
    /// The edge the toast slides in from.
    var edge: Edge = .bottom

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let message = center.current {
                ToastView(message: message, onUndo: center.performUndo)
                    .id(message.id)
                    .transition(FolioMotion.transition(.move(edge: edge).combined(with: .opacity), reduceMotion: reduceMotion))
            }
        }
        .animation(FolioMotion.toast(reduceMotion: reduceMotion), value: center.current)
    }
}

/// Presents toasts just above the tab bar (owner review, Batch B): never over the floating
/// "+" or another bottom control. With `trailingClearance`, the toast shares the "+" row,
/// leading-aligned, so it sits in the space lists already keep clear for the button.
///
/// Attach it inside each tab's content, not on the `TabView`: an overlay on the `TabView`
/// draws on top but doesn't receive touches, so Undo would fall through to the list below.
/// To-do doesn't use this: its toast rides in the quick-add bar's safe-area inset.
struct ToastHostModifier: ViewModifier {
    let center: ToastCenter
    var trailingClearance: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: trailingClearance > 0 ? .bottomLeading : .bottom) {
            ToastSlot(center: center)
                .padding(.leading, Spacing.sideMargin)
                .padding(.trailing, Spacing.sideMargin + trailingClearance)
                .padding(.bottom, FloatingButtonMetrics.toastBottomPadding)
                .animation(FolioMotion.toast(reduceMotion: reduceMotion), value: trailingClearance)
        }
    }
}

extension View {
    func toastHost(_ center: ToastCenter, trailingClearance: Double = 0) -> some View {
        modifier(ToastHostModifier(center: center, trailingClearance: trailingClearance))
    }
}
