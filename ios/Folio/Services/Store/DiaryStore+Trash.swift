import Foundation
import SwiftData

/// Recently Deleted (SPEC §5.2): Delete moves an entry (with its photos), task or category to
/// the trash by setting `trashedAt`. Every live query skips trashed records. Items stay 30
/// days, then `purgeExpiredTrash()` deletes them permanently.
extension DiaryStore {
    /// How long items stay in Recently Deleted.
    static let trashRetentionDays = 30
    static let trashClockKey = "trashClockHighWater"

    // MARK: Reading

    func trashedEntries() -> [Entry] {
        _ = revision
        return fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone },
                                            sortBy: [SortDescriptor(\.trashedAt, order: .reverse)]))
    }

    func trashedTasks() -> [TaskItem] {
        _ = revision
        return fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone },
                                               sortBy: [SortDescriptor(\.trashedAt, order: .reverse)]))
    }

    func trashedCategories() -> [Category] {
        _ = revision
        return fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone },
                                               sortBy: [SortDescriptor(\.trashedAt, order: .reverse)]))
    }

    /// Everything in Recently Deleted, for the "Recently Deleted · N" rows and links.
    var trashCount: Int {
        _ = revision
        return fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone }))
            + fetchCount(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone }))
            + fetchCount(FetchDescriptor<Category>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone }))
    }

    /// A trashed entry by id, for the read-only preview.
    func trashedEntry(id: UUID) -> Entry? {
        trashedEntries().first { $0.id == id }
    }

    /// Whole days left before the purge, 0…30. Uses the high-water clock, so it never grows
    /// when the device clock moves backwards.
    func daysLeft(trashedAt: Date) -> Int {
        let expiry = trashedAt.addingTimeInterval(Self.retention)
        let seconds = expiry.timeIntervalSince(trashClockNow())
        return min(Self.trashRetentionDays, max(0, Int((seconds / 86_400).rounded(.up))))
    }

    // MARK: Trash

    /// Moves an entry and its photos to Recently Deleted. The photos stay attached and come
    /// back with it.
    func trash(_ entry: Entry) {
        stampTrashed(entry)
        commit()
    }

    func trash(_ task: TaskItem) {
        stampTrashed(task)
        commit()
    }

    /// Moves a category to Recently Deleted. Its entries and tasks keep their content and lose
    /// the category; their ids are kept so a restore can re-link them. Returns how many.
    @discardableResult
    func trash(_ category: Category) -> Int {
        let stamp = trashClockNow()
        category.unassignedIDs = unassign(category, at: stamp)
        stampTrashed(category, at: stamp)
        commit()
        return category.unassignedIDs?.count ?? 0
    }

    // MARK: Restore

    /// Back on its original day with its category, if that category is still live.
    func restoreFromTrash(_ entry: Entry) {
        if category(id: entry.categoryID) == nil { entry.categoryID = nil }
        clearTrashed(entry)
        commit()
    }

    /// A completed task stays completed.
    func restoreFromTrash(_ task: TaskItem) {
        if category(id: task.categoryID) == nil { task.categoryID = nil }
        clearTrashed(task)
        commit()
    }

    /// Re-links the entries and tasks it un-assigned, unless they've been given another
    /// category since. A name now taken by a live category gets a number.
    func restoreFromTrash(_ category: Category) throws(StoreError) {
        guard categories().count < Category.maximumCount else { throw .tooManyCategories }
        category.name = availableName(for: category.name)
        let stamp = trashClockNow()
        let ids = Set(category.unassignedIDs ?? [])
        if !ids.isEmpty {
            let categoryID: UUID? = category.id
            for entry in fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.categoryID == nil && !$0.isTombstone }))
            where ids.contains(entry.id) {
                entry.categoryID = categoryID
                entry.markChanged(at: stamp)
            }
            for task in fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.categoryID == nil && !$0.isTombstone }))
            where ids.contains(task.id) {
                task.categoryID = categoryID
                task.markChanged(at: stamp)
            }
        }
        category.unassignedIDs = nil
        category.sortIndex = (categories().map(\.sortIndex).max() ?? -1) + 1
        clearTrashed(category)
        commit()
    }

    // MARK: Delete now, Empty, purge

    /// Permanently deletes everything in Recently Deleted.
    func emptyTrash() {
        for entry in trashedEntries() { deletePermanently(entry) }
        for task in trashedTasks() { deletePermanently(task) }
        for category in trashedCategories() { deletePermanently(category) }
    }

    /// Permanently deletes items trashed more than 30 days ago (SPEC §5.2). Runs on launch,
    /// on foreground and in background refresh, while protected data is available.
    /// Returns how many records it removed.
    @discardableResult
    func purgeExpiredTrash() -> Int {
        let cutoff = trashClockNow().addingTimeInterval(-Self.retention)
        let entries = fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone }))
            .filter { ($0.trashedAt ?? .distantFuture) <= cutoff }
        let tasks = fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone }))
            .filter { ($0.trashedAt ?? .distantFuture) <= cutoff }
        let categories = fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.trashedAt != nil && !$0.isTombstone }))
            .filter { ($0.trashedAt ?? .distantFuture) <= cutoff }
        for entry in entries { deletePermanently(entry) }
        for task in tasks { deletePermanently(task) }
        for category in categories { deletePermanently(category) }
        return entries.count + tasks.count + categories.count
    }

    // MARK: Clock

    /// `max(now, the latest now seen)`: the Recently Deleted clock never runs backwards, so a
    /// device clock moved back can't stretch a countdown or confuse the purge (SPEC §5.2).
    func trashClockNow() -> Date {
        let current = now()
        let stored = trashClockHighWater ?? trashClockDefaults?.object(forKey: Self.trashClockKey) as? Date
        let effective = max(current, stored ?? current)
        if effective != stored {
            trashClockHighWater = effective
            trashClockDefaults?.set(effective, forKey: Self.trashClockKey)
        }
        return effective
    }

    private static var retention: TimeInterval { TimeInterval(trashRetentionDays) * 86_400 }

    private func stampTrashed(_ record: some TrashableRecord, at stamp: Date? = nil) {
        let stamp = stamp ?? trashClockNow()
        record.trashedAt = stamp
        record.markChanged(at: stamp)
    }

    private func clearTrashed(_ record: some TrashableRecord) {
        record.trashedAt = nil
        record.markChanged(at: trashClockNow())
    }

    private func availableName(for name: String) -> String {
        let taken = Set(categories().map { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) })
        func isFree(_ candidate: String) -> Bool {
            !taken.contains(candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))
        }
        guard !isFree(name) else { return name }
        for number in 2...99 {
            let suffix = " \(number)"
            let candidate = String(name.prefix(Category.nameLengths.upperBound - suffix.count)) + suffix
            if isFree(candidate) { return candidate }
        }
        return name
    }
}
