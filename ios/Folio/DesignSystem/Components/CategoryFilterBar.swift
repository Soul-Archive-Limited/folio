import SwiftUI

/// Horizontal category chips used as a filter on To-do and Journal (SPEC §6.6, §6.7).
struct CategoryFilterBar: View {
    @Binding var selection: Set<UUID>
    @Environment(DiaryStore.self) private var store

    var body: some View {
        let categories = store.categories()
        if !categories.isEmpty {
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 0) {
                    HStack(spacing: Spacing.xs) {
                        Chip(title: String(localized: "All"), isSelected: selection.isEmpty) { selection.removeAll() }
                        ForEach(categories) { category in
                            Chip(title: category.name, systemImage: category.symbol, category: category.color,
                                 isSelected: selection.contains(category.id)) { toggle(category.id) }
                        }
                    }
                }
                .padding(.horizontal, Spacing.sideMargin)
            }
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: false, vertical: true)
            // Chips share one glass container and the scroll view doesn't clip: separate glass
            // shapes in a clipping scroll view showed a lighter band behind them.
            .scrollClipDisabled()
        }
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
}
