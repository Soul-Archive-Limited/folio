import Foundation
import SwiftData

/// An in-memory index of the diary for search (Batch J). Built off the main thread from the
/// SwiftData store and kept only in memory — nothing readable is written anywhere new, and
/// nothing leaves the device. Each document keeps a sorted vocabulary, so a query is a
/// binary search per word per document: a few milliseconds on 10,000 entries.
nonisolated struct SearchIndex: Sendable {
    enum Kind: Sendable { case entry, task }

    struct Document: Identifiable, Sendable {
        let id: UUID
        let kind: Kind
        let dayKey: String?
        let minutesFromMidnight: Int?
        let categoryID: UUID?
        let title: String
        /// Entry body as plain text, or task notes; shown as the snippet.
        let text: String
        /// Subtask titles (tasks only).
        let subtasks: [String]
        let firstPhotoID: UUID?
        let photoCount: Int
        let isCompleted: Bool
        let mood: Int?
        let vocabulary: [String]
    }

    var documents: [Document] = []
    /// Folded category names by id; a category's name matches its pages and tasks.
    var categoryWords: [UUID: [String]] = [:]

    func search(_ query: SearchQuery) -> [Document] {
        let terms = query.terms
        let categoryHits: [String: Set<UUID>] = Dictionary(uniqueKeysWithValues: terms.map { term in
            (term, Set(categoryWords.compactMap { id, words in words.contains { $0.hasPrefix(term) } ? id : nil }))
        })
        return documents.filter { document in
            guard query.filters.admits(document) else { return false }
            return terms.allSatisfy { term in
                SearchText.vocabulary(document.vocabulary, hasPrefix: term)
                    || document.categoryID.map { categoryHits[term]?.contains($0) == true } == true
            }
        }
    }
}

/// What the person typed plus the filters.
nonisolated struct SearchQuery: Equatable, Sendable {
    var text = ""
    var filters = SearchFilters()

    var terms: [String] { Array(Set(SearchText.words(in: text))).sorted() }
    /// Nothing typed and no filter: show nothing rather than the whole diary.
    var isEmpty: Bool { terms.isEmpty && !filters.isActive }
}

nonisolated struct SearchFilters: Equatable, Sendable {
    enum Scope: Sendable { case everything, tasksOnly }
    enum Status: String, CaseIterable, Sendable { case any, open, done }

    var scope = Scope.everything
    var categories: Set<UUID> = []
    var hasPhotos = false
    var from: DayKey?
    var through: DayKey?
    var status = Status.any

    /// Filters the person set (scope is the screen's, not theirs).
    var isActive: Bool { !categories.isEmpty || hasPhotos || from != nil || through != nil || status != .any }

    func admits(_ document: SearchIndex.Document) -> Bool {
        switch document.kind {
        case .entry:
            // Open/done is about tasks; asking for it shows tasks only.
            if scope == .tasksOnly || status != .any { return false }
            if hasPhotos && document.photoCount == 0 { return false }
        case .task:
            if hasPhotos { return false }
            if status == .open && document.isCompleted { return false }
            if status == .done && !document.isCompleted { return false }
        }
        if !categories.isEmpty {
            guard let id = document.categoryID, categories.contains(id) else { return false }
        }
        if from != nil || through != nil {
            guard let raw = document.dayKey else { return false }
            if let from, raw < from.rawValue { return false }
            if let through, raw > through.rawValue { return false }
        }
        return true
    }
}
