import SwiftUI

/// iPad and other wide windows (Batch L): lists and timelines keep a readable column, centred,
/// instead of stretching rows and cover photos across a 13-inch screen. Below the limit (iPhone,
/// narrow Split View) it changes nothing.
struct ReadableWidth: ViewModifier {
    var maxWidth: Double = 760
    @State private var width: Double = 0

    func body(content: Content) -> some View {
        let extra = max(0, (width - maxWidth) / 2)
        content
            .contentMargins(.horizontal, extra, for: .scrollContent)
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
    }
}

extension View {
    func readableWidth(_ maxWidth: Double = 760) -> some View { modifier(ReadableWidth(maxWidth: maxWidth)) }
}
