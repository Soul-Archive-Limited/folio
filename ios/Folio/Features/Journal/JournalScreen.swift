import SwiftUI

/// The Journal tab (SPEC §6.6): Timeline or Photos, filtered by category.
struct JournalScreen: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.newItemRequest) private var request
    @Bindable var model: JournalModel
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $model.path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.m, pinnedViews: .sectionHeaders) {
                    JournalControls(model: model) { request?.send(.pastEntry) }
                    if store.allEntries().isEmpty {
                        EmptyStateView(systemImage: "book.pages", message: "Your journal is empty. Tap + to write your first page.")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else if model.mode == .timeline {
                        JournalTimeline(sections: model.sections(store: store), zoom: zoom)
                    } else {
                        JournalPhotoGrid(photos: model.photos(store: store), zoom: zoom)
                            .padding(.horizontal, Spacing.sideMargin)
                    }
                }
                .padding(.bottom, FloatingButtonMetrics.clearance + Spacing.l)
            }
            .background { AuraBackground() }
            .navigationTitle("Journal")
            .navigationDestination(for: UUID.self) { id in
                EntryDetailView(entryID: id)
                    .navigationTransition(.zoom(sourceID: id, in: zoom))
            }
        }
        #if DEBUG
        .onAppear { model.applyDebugOptions() }
        #endif
    }
}

#Preview {
    JournalScreen(model: JournalModel())
        .environment(PreviewData.previewStore())
        .environment(ToastCenter())
}

#if DEBUG
extension JournalModel {
    func applyDebugOptions() {
        if DebugLaunchOptions.string("FolioJournalMode") == "photos" { mode = .photos }
    }
}
#endif
