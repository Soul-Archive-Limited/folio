import SwiftUI

/// Rows rise 20 pt and fade in, 30 ms apart (SPEC §3.6). Under Reduce Motion they only fade.
struct StaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : FolioMotion.staggerRise)
            .task {
                let delay = Double(min(index, 10)) * 0.03
                withAnimation(FolioMotion.standard(reduceMotion: reduceMotion).delay(reduceMotion ? 0 : delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
