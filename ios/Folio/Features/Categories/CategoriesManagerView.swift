import SwiftUI

/// Categories (SPEC §6.10): colour, symbol, name and how many items use each. Drag to
/// reorder, swipe to delete (with counts), tap to edit. Up to 30.
struct CategoriesManagerView: View {
    @Environment(DiaryStore.self) private var store
    @State private var editing: CategoryEditTarget?
    @State private var deleting: Category?

    var body: some View {
        let categories = store.categories()
        List {
            if categories.isEmpty {
                EmptyStateView(systemImage: "tag", message: "Make categories with your own colours.")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            ForEach(categories) { category in
                Button { editing = .existing(category) } label: {
                    CategoryManagerRow(category: category, usage: store.usage(of: category))
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = category }
                }
            }
            .onMove { indices, offset in
                var reordered = categories
                reordered.move(fromOffsets: indices, toOffset: offset)
                store.reorderCategories(reordered)
            }
            if categories.count >= Category.maximumCount {
                Text("You've reached 30 categories.")
                    .folioFont(.callout).foregroundStyle(.inkSecondary)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background { AuraBackground() }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New category", systemImage: "plus") { editing = .new }
                    .disabled(categories.count >= Category.maximumCount)
            }
        }
        .sheet(item: $editing) { target in CategoryEditSheet(target: target) }
        .confirmationDialog(deleteTitle, isPresented: isDeleting, titleVisibility: .visible, presenting: deleting) { category in
            Button("Delete category", role: .destructive) { store.delete(category) }
        } message: { category in
            Text(deleteMessage(category))
        }
        .folioHaptic(.warning, trigger: deleting?.id)
    }

    private var deleteTitle: String {
        String(localized: "Delete “\(deleting?.name ?? "")”?")
    }

    /// "3 entries and 2 tasks will keep their content and lose this category."
    private func deleteMessage(_ category: Category) -> String {
        let usage = store.usage(of: category)
        if usage.entries == 0 && usage.tasks == 0 { return String(localized: "Nothing uses this category.") }
        let entries = String(AttributedString(localized: "^[\(usage.entries) entry](inflect: true)").characters)
        let tasks = String(AttributedString(localized: "^[\(usage.tasks) task](inflect: true)").characters)
        return String(localized: "\(entries) and \(tasks) will keep their content and lose this category.")
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
}

/// What the edit sheet is editing.
enum CategoryEditTarget: Identifiable {
    case new
    case existing(Category)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let category): category.id.uuidString
        }
    }
}

#Preview {
    NavigationStack { CategoriesManagerView() }
        .environment(PreviewData.previewStore())
}
