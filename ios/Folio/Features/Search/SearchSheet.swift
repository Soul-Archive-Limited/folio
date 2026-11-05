import SwiftUI

/// Calendar's search (Batch J): pull the day panel down, or tap the magnifier. A full sheet
/// with the field already focused; results open inside it, so Back returns to them.
struct SearchSheet: View {
    @State private var model = SearchModel()
    @State private var path: [UUID] = []
    @State private var editingTask: TaskItem?
    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            SearchResultsView(model: model, onOpenEntry: { path.append($0) },
                              onOpenTask: { id in editingTask = store.task(id: id) })
                .background { AuraBackground() }
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $model.text, isPresented: $model.isPresented,
                            placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search your diary"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationDestination(for: UUID.self) { id in EntryDetailView(entryID: id) }
        }
        .searchIndexFeed(model)
        .toastHost(toasts)
        .sheet(item: $editingTask) { task in TaskComposerSheet(task: task, day: nil) }
        .onAppear {
            model.isPresented = true
            #if DEBUG
            model.applyDebugText()
            #endif
        }
    }
}
