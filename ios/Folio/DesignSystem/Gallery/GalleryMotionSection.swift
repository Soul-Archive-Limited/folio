#if DEBUG
import SwiftUI

struct GalleryMotionSection: View {
    @State private var expanded = false
    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GallerySection(title: "Motion · glass morph") {
            GlassEffectContainer(spacing: Spacing.xl) {
                HStack(spacing: Spacing.s) {
                    Button(expanded ? "Collapse" : "Expand", systemImage: expanded ? "xmark" : "plus", action: toggle)
                        .labelStyle(.iconOnly)
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.white)
                        .glassEffect(.regular.tint(.emberStrong).interactive(), in: .circle)
                        .glassEffectID("plus", in: glass)
                    if expanded {
                        Label("New entry", systemImage: "square.and.pencil")
                            .padding(.horizontal, Spacing.m)
                            .frame(height: 56)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .glassEffectID("entry", in: glass)
                            .glassEffectTransition(.matchedGeometry)
                        Label("New task", systemImage: "checklist")
                            .padding(.horizontal, Spacing.m)
                            .frame(height: 56)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .glassEffectID("task", in: glass)
                            .glassEffectTransition(.matchedGeometry)
                    }
                }
            }
            .foregroundStyle(.ink)
        }
    }

    private func toggle() {
        withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { expanded.toggle() }
    }
}
#endif
