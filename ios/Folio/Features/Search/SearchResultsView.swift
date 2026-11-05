import SwiftUI

/// The results under a search field (Batch J): filters, then Pages and Tasks. Tapping a result
/// opens it where the search is — pushed in the same stack, or the task sheet.
struct SearchResultsView: View {
    @Bindable var model: SearchModel
    let onOpenEntry: (UUID) -> Void
    let onOpenTask: (UUID) -> Void

    @Environment(DiaryStore.self) private var store
    @Environment(SearchCenter.self) private var center

    /// Long result lists are cut here; a footer says how many more there are.
    private static let pageLimit = 300

    var body: some View {
        let categories = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0) })
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.s) {
                SearchFilterBar(model: model)
                    .padding(.horizontal, -Spacing.sideMargin)
                if center.isBuilding {
                    ProgressView("Getting your diary ready…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if !model.isActive {
                    EmptyStateView(systemImage: "magnifyingglass",
                                   message: model.filters.scope == .tasksOnly ? "Search your tasks and subtasks."
                                       : "Search titles, pages, categories and tasks. Everything stays on this iPhone.")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if model.entries.isEmpty && model.tasks.isEmpty {
                    EmptyStateView(systemImage: "text.page.badge.magnifyingglass", message: LocalizedStringKey(noMatchesMessage))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    if !model.entries.isEmpty {
                        header(String(localized: "Pages"), count: model.entries.count)
                        ForEach(model.entries.prefix(Self.pageLimit)) { document in
                            Button { onOpenEntry(document.id) } label: {
                                SearchEntryRow(document: document, terms: model.terms, category: document.categoryID.flatMap { categories[$0] })
                            }
                            .buttonStyle(.pressable)
                        }
                        if model.entries.count > Self.pageLimit {
                            Text("\(model.entries.count - Self.pageLimit) more — add a word or a filter to narrow it down.")
                                .folioFont(.caption).foregroundStyle(.inkSecondary)
                        }
                    }
                    if !model.tasks.isEmpty {
                        header(String(localized: "Tasks"), count: model.tasks.count)
                        ForEach(model.tasks.prefix(Self.pageLimit)) { document in
                            Button { onOpenTask(document.id) } label: {
                                SearchTaskRow(document: document, terms: model.terms, category: document.categoryID.flatMap { categories[$0] })
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.bottom, FloatingButtonMetrics.clearance + Spacing.l)
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("search-results")
    }

    private var noMatchesMessage: String {
        model.text.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Nothing matches these filters.")
            : String(localized: "No matches for “\(model.text.trimmingCharacters(in: .whitespaces))”.")
    }

    private func header(_ title: String, count: Int) -> some View {
        Text("\(title) · \(count)")
            .folioFont(.caption)
            .foregroundStyle(.inkSecondary)
            .textCase(.uppercase)
            .padding(.top, Spacing.s)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Keeps a search field fed with the current index: refreshed in the background while the
    /// field is open, re-run whenever a new index lands (Batch J).
    func searchIndexFeed(_ model: SearchModel) -> some View {
        modifier(SearchIndexFeed(model: model))
    }
}

private struct SearchIndexFeed: ViewModifier {
    let model: SearchModel
    @Environment(DiaryStore.self) private var store
    @Environment(SearchCenter.self) private var center

    func body(content: Content) -> some View {
        content
            .onChange(of: model.isPresented || model.isActive, initial: true) { _, on in
                if on { center.refresh(store: store) }
            }
            .onChange(of: store.revision) {
                if model.isPresented || model.isActive { center.refresh(store: store) }
            }
            .onChange(of: center.generation, initial: true) { model.use(center.index) }
    }
}
