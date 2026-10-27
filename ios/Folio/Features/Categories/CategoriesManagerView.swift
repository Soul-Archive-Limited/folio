import SwiftUI

/// Categories (SPEC §6.10): colour, symbol, name and how many items use each. Drag to
/// reorder, swipe to move to Recently Deleted (SPEC §5.2), tap to edit. Up to 30.
struct CategoriesManagerView: View {
    @Environment(DiaryStore.self) private var store
    @State private var editing: CategoryEditTarget?
    @Environment(ToastCenter.self) private var toasts: ToastCenter?

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
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(category) }
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
        #if DEBUG
        .task {
            if DebugLaunchOptions.string("FolioOpen") == "categoryEdit", let first = store.categories().first {
                try? await Task.sleep(for: .milliseconds(400))
                editing = .existing(first)
            }
        }
        #endif
    }

    /// Straight to Recently Deleted (SPEC §5.2). Its entries and tasks keep their content and
    /// lose the category; Undo or Restore re-links them.
    private func delete(_ category: Category) {
        store.trash(category)
        toasts?.show(.movedToTrash { try? store.restoreFromTrash(category) })
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

#if DEBUG
#Preview {
    NavigationStack { CategoriesManagerView() }
        .environment(PreviewData.previewStore())
}
#endif
