import SwiftUI

/// Compact screen headers (owner's test, Batch I: headers took too much space). The screen's
/// title sits in its content at a smaller size than a large title; once it scrolls away, it
/// returns as a slim glass pill in the top bar. No full-width bar, no extra container.
struct CompactTitleText: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(.title, design: .default, weight: .bold))
            .foregroundStyle(.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

struct CompactTitleModifier: ViewModifier {
    let title: LocalizedStringKey
    /// How far the content scrolls before the pill shows (about the in-content title's height).
    var threshold: Double = 34

    @State private var showsPill = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.ink)
                        .padding(.horizontal, Spacing.m)
                        .frame(height: 32)
                        .glassEffect(.regular, in: .capsule)
                        .opacity(showsPill ? 1 : 0)
                        .scaleEffect(showsPill || reduceMotion ? 1 : 0.9)
                        .animation(reduceMotion ? FolioMotion.reduced : .smooth(duration: 0.25), value: showsPill)
                        .accessibilityHidden(!showsPill)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > threshold
            } action: { _, scrolled in
                showsPill = scrolled
            }
    }
}

extension View {
    /// A compact in-content title that collapses into a glass pill in the top bar on scroll.
    func compactTitle(_ title: LocalizedStringKey) -> some View {
        modifier(CompactTitleModifier(title: title))
    }
}
