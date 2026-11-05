import Foundation
import SwiftData

/// Builds `SearchIndex` on its own context, off the main thread. Entry documents are cached by
/// a hash of what they show, so after the first build only changed pages are re-split
/// (Batch J). Not `updatedAt`: two edits can share a timestamp.
actor SearchIndexer {
    private struct CachedEntry {
        let signature: Int
        let document: SearchIndex.Document
    }

    private var entryCache: [UUID: CachedEntry] = [:]

    func build(container: ModelContainer) -> SearchIndex {
        let context = ModelContext(container)
        var index = SearchIndex()

        let categories = (try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { !$0.isTombstone && $0.trashedAt == nil }))) ?? []
        index.categoryWords = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, SearchText.words(in: $0.name)) })

        let entries = (try? context.fetch(FetchDescriptor<Entry>(
            predicate: #Predicate { !$0.isTombstone && $0.trashedAt == nil },
            sortBy: [SortDescriptor(\.dayKey, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? []
        var fresh: [UUID: CachedEntry] = [:]
        var documents: [SearchIndex.Document] = []
        documents.reserveCapacity(entries.count)
        for entry in entries {
            let photos = entry.orderedPhotos
            var hasher = Hasher()
            hasher.combine(entry.title)
            hasher.combine(entry.bodyMarkdown)
            hasher.combine(entry.dayKey)
            hasher.combine(entry.minutesFromMidnight)
            hasher.combine(entry.categoryID)
            hasher.combine(photos.first?.id)
            hasher.combine(photos.count)
            let signature = hasher.finalize()
            if let cached = entryCache[entry.id], cached.signature == signature {
                fresh[entry.id] = cached
                documents.append(cached.document)
                continue
            }
            let text = MarkdownCodec.document(from: entry.bodyMarkdown).plainText
            let document = SearchIndex.Document(
                id: entry.id, kind: .entry, dayKey: entry.dayKey, minutesFromMidnight: entry.minutesFromMidnight,
                categoryID: entry.categoryID, title: entry.title, text: text, subtasks: [],
                firstPhotoID: photos.first?.id, photoCount: photos.count, isCompleted: false, mood: nil,
                vocabulary: SearchText.vocabulary(of: [entry.title, text])
            )
            fresh[entry.id] = CachedEntry(signature: signature, document: document)
            documents.append(document)
        }
        entryCache = fresh

        // Tasks are short; they're re-read every time (subtask edits don't touch the parent).
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isTombstone && $0.trashedAt == nil }))) ?? []
        let subtasks = Dictionary(grouping: tasks.filter { $0.parentID != nil }) { $0.parentID ?? UUID() }
        let parents = tasks.filter { $0.parentID == nil }.sorted { ($0.dayKey ?? "", $0.sortIndex) > ($1.dayKey ?? "", $1.sortIndex) }
        for task in parents {
            let children = (subtasks[task.id] ?? []).sorted { $0.sortIndex < $1.sortIndex }.map(\.title)
            documents.append(SearchIndex.Document(
                id: task.id, kind: .task, dayKey: task.dayKey, minutesFromMidnight: task.minutesFromMidnight,
                categoryID: task.categoryID, title: task.title, text: task.notes ?? "", subtasks: children,
                firstPhotoID: nil, photoCount: 0, isCompleted: task.isCompleted, mood: nil,
                vocabulary: SearchText.vocabulary(of: [task.title, task.notes ?? ""] + children)
            ))
        }
        index.documents = documents
        return index
    }

    /// Erase and sign-out: nothing of the old diary stays in memory.
    func reset() {
        entryCache = [:]
    }
}
