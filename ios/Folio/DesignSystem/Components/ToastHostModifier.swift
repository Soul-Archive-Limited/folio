import SwiftUI

/// Presents `ToastCenter` toasts at the bottom of the view it's attached to. Toasts rise
/// from the bottom and leave the same way; under Reduce Motion they only fade.
struct ToastHostModifier: ViewModifier {
    let center: ToastCenter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let message = center.current {
                    ToastView(message: message, onUndo: center.performUndo)
                        .id(message.id)
                        .transition(FolioMotion.transition(.move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.bottom, Spacing.xs)
            .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: center.current)
        }
    }
}

extension View {
    func toastHost(_ center: ToastCenter) -> some View {
        modifier(ToastHostModifier(center: center))
    }
}
