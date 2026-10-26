import SwiftUI

/// Softens the bottom edge of a scroll view that ends above floating controls, so rows
/// fade out instead of being cut by a hard line.
struct ScrollEdgeFade: ViewModifier {
    var height: Double = 24

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: height)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

extension View {
    func scrollEdgeFade(height: Double = 24) -> some View {
        modifier(ScrollEdgeFade(height: height))
    }
}
