#if DEBUG
import SwiftUI

struct GalleryComponentsSection: View {
    @State private var selected: Set<CategoryColor> = [.ocean]

    var body: some View {
        GallerySection(title: "Glass components") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                GlassCard {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Glass card").folioFont(.headline)
                        Text("Radius 22. Nested shapes use ConcentricRectangle.")
                            .folioFont(.callout).foregroundStyle(.inkSecondary)
                        ConcentricRectangle()
                            .fill(.ember.opacity(0.18))
                            .frame(height: 44)
                    }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.xs) {
                        ForEach([CategoryColor.ocean, .sage, .plum, .sand], id: \.self) { category in
                            Chip(title: String(localized: category.displayName), category: category,
                                 isSelected: selected.contains(category)) { toggle(category) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                GlassEffectContainer(spacing: Spacing.s) {
                    HStack(spacing: Spacing.s) {
                        GlassIconButton(title: "Filter", systemImage: "line.3.horizontal.decrease") {}
                        GlassIconButton(title: "New entry", systemImage: "plus", prominent: true) {}
                        Button("Today") {}.buttonStyle(.glass)
                        Button("Save") {}.buttonStyle(.glassProminent).tint(.emberStrong)
                        Button("Delete", role: .destructive) {}.buttonStyle(.glass).tint(.danger)
                    }
                }
                EmptyStateView(systemImage: "book.pages", message: "Nothing here yet.")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func toggle(_ category: CategoryColor) {
        if selected.contains(category) { selected.remove(category) } else { selected.insert(category) }
    }
}
#endif
