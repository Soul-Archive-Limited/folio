import Foundation

/// One search field's state (Calendar, Journal, To-do): the text, the filters and the results,
/// recomputed when either changes or the index is rebuilt (Batch J).
@Observable
final class SearchModel {
    var text = "" { didSet { if text != oldValue { scheduleSearch() } } }
    var filters: SearchFilters { didSet { if filters != oldValue { scheduleSearch(immediately: true) } } }
    var isPresented = false
    private(set) var entries: [SearchIndex.Document] = []
    private(set) var tasks: [SearchIndex.Document] = []
    private(set) var terms: [String] = []
    /// True once a query or filter is in play; the screen swaps its content for the results.
    var isActive: Bool { !query.isEmpty }

    @ObservationIgnored private var index = SearchIndex()
    @ObservationIgnored private var debounce: Task<Void, Never>?

    init(scope: SearchFilters.Scope = .everything) {
        filters = SearchFilters(scope: scope)
    }

    var query: SearchQuery { SearchQuery(text: text, filters: filters) }

    /// The index changed (first build, or a write since).
    func use(_ index: SearchIndex) {
        self.index = index
        run()
    }

    #if DEBUG
    /// `-FolioSearch "text"`: open with that text (screenshots).
    func applyDebugText() {
        guard let text = DebugLaunchOptions.searchText else { return }
        isPresented = true
        self.text = text
    }
    #endif

    private func scheduleSearch(immediately: Bool = false) {
        debounce?.cancel()
        if immediately || text.isEmpty { run(); return }
        // Typing: wait for a short pause so each keystroke doesn't redraw the list.
        debounce = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            run()
        }
    }

    private func run() {
        let query = query
        terms = query.terms
        guard !query.isEmpty else {
            entries = []
            tasks = []
            return
        }
        let hits = index.search(query)
        entries = hits.filter { $0.kind == .entry }
        tasks = hits.filter { $0.kind == .task }
    }
}
