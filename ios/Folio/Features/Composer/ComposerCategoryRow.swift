import SwiftUI

/// Category chips under the title, with an inline "+" to create one (SPEC §6.4).
struct ComposerCategoryRow: View {
    @Binding var selection: UUID?

    @Environment(DiaryStore.self) private var store
    @State private var showsNewCategory = false
    @State private var newName = ""

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(store.categories()) { category in
                    Chip(title: category.name, systemImage: category.symbol, category: category.color,
                         isSelected: selection == category.id) {
                        selection = selection == category.id ? nil : category.id
                    }
                }
                Chip(title: String(localized: "New"), systemImage: "plus") { showsNewCategory = true }
                    .accessibilityLabel("New category")
            }
        }
        .scrollIndicators(.hidden)
        // A horizontal ScrollView is greedy vertically; keep the row at its natural height.
        .fixedSize(horizontal: false, vertical: true)
        .alert("New category", isPresented: $showsNewCategory) {
            TextField("Name", text: $newName)
            Button("Create", action: create)
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Up to 24 characters.")
        }
    }

    private func create() {
        let used = Set(store.categories().map(\.colorKey))
        let color = CategoryColor.allCases.first { !used.contains($0.rawValue) } ?? .graphite
        if let category = try? store.createCategory(name: newName, color: color) {
            selection = category.id
        }
        newName = ""
    }
}
