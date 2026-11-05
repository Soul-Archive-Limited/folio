import Foundation
import SwiftData

/// Owns the in-memory search index for the whole app (Batch J) and keeps it in step with the
/// store: a rebuild runs in the background after writes, only while a search is on screen,
/// so an idle app does no work. Deleted and erased pages drop out on the next build.
@Observable
final class SearchCenter {
    private(set) var index = SearchIndex()
    /// Bumped whenever `index` is replaced, so search fields re-run their query.
    private(set) var generation = 0
    private(set) var isBuilding = false
    @ObservationIgnored private var builtRevision = -1
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private let indexer = SearchIndexer()

    /// Builds or refreshes the index for the store's current revision.
    func refresh(store: DiaryStore) {
        let target = store.revision
        guard target != builtRevision, pending == nil else { return }
        let container = store.context.container
        isBuilding = builtRevision < 0
        pending = Task { [indexer] in
            let index = await indexer.build(container: container)
            self.index = index
            self.builtRevision = target
            self.generation += 1
            self.isBuilding = false
            self.pending = nil
            // Writes that landed while building: go again.
            if store.revision != target { self.refresh(store: store) }
        }
    }
}
