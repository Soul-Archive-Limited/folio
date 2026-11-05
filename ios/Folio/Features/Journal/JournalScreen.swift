import SwiftUI

/// The Journal tab (SPEC §6.6): Timeline or Photos, filtered by category.
struct JournalScreen: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.newItemRequest) private var request
    @Bindable var model: JournalModel
    @Namespace private var zoom
    /// Pull down for search (Batch J); while it's open the results replace the timeline.
    @State private var search = SearchModel()
    @State private var editingTask: TaskItem?

    var body: some View {
        NavigationStack(path: $model.path) {
            Group {
                if search.isPresented || search.isActive {
                    SearchResultsView(model: search, onOpenEntry: { model.path.append($0) },
                                      onOpenTask: { editingTask = store.task(id: $0) })
                } else {
                    timeline
                }
            }
            .background { AuraBackground() }
            .compactTitle("Journal")
            .searchable(text: $search.text, isPresented: $search.isPresented,
                        placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text("Search your diary"))
            .searchIndexFeed(search)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Labelled, not just the glyph (owner's iPhone test, Batch E).
                    Button { request?.send(.pastEntry) } label: {
                        // An HStack, not a Label: the top bar shows a Label as its icon only.
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Past day")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel("Write for a past day")
                    .accessibilityIdentifier("journal.pastDay")
                }
            }
            .navigationDestination(isPresented: $model.showsTrash) { RecentlyDeletedView() }
            .navigationDestination(for: UUID.self) { id in
                EntryDetailView(entryID: id)
                    .navigationTransition(.zoom(sourceID: id, in: zoom))
            }
        }
        .sheet(item: $editingTask) { task in TaskComposerSheet(task: task, day: nil) }
        #if DEBUG
        .onAppear {
            model.applyDebugOptions()
            search.applyDebugText()
        }
        #endif
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.m) {
                JournalControls(model: model)
                if !store.hasEntries {
                    EmptyStateView(systemImage: "book.pages", message: "Your journal is empty. Tap + to write your first page.")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if model.mode == .timeline {
                    JournalTimeline(sections: model.sections(store: store), model: model, today: store.today, zoom: zoom)
                } else {
                    JournalPhotoGrid(photos: model.photos(store: store), zoom: zoom)
                        .padding(.horizontal, Spacing.sideMargin)
                }
                if model.mode == .timeline, store.trashCount > 0 {
                    RecentlyDeletedLink(count: store.trashCount) { model.showsTrash = true }
                        .padding(.top, Spacing.s)
                }
            }
            .padding(.bottom, FloatingButtonMetrics.clearance + Spacing.l)
        }
    }
}

#if DEBUG
#Preview {
    JournalScreen(model: JournalModel())
        .environment(PreviewData.previewStore())
        .environment(ToastCenter())
}
#endif

#if DEBUG
extension JournalModel {
    func applyDebugOptions() {
        if DebugLaunchOptions.string("FolioJournalMode") == "photos" { mode = .photos }
    }
}
#endif
