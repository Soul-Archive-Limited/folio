import Foundation
import os
import SwiftData

/// The app's single source of truth for diary data (SPEC §0.4, §5). Every write goes to
/// SwiftData first and is saved immediately; sync (Phase 10) reads the dirty flags.
///
/// Views observe `revision`: every read method touches it, every write bumps it.
@Observable
final class DiaryStore {
    let context: ModelContext
    /// The phone's calendar: decides what "today" is. Never used to place stored items.
    var calendar: Calendar
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored var drafts = DraftStore()
    /// Keeps the Recently Deleted clock's high-water mark (SPEC §5.2). Nil keeps it in memory only.
    @ObservationIgnored let trashClockDefaults: UserDefaults?
    @ObservationIgnored var trashClockHighWater: Date?

    private(set) var revision = 0
    /// Bumped when synced photo bytes finish downloading, so image views load them.
    var photoBytesRevision = 0
    /// Called after every local write, so sync can schedule a push (Phase 10).
    @ObservationIgnored var onLocalChange: (() -> Void)?
    /// Called after "Erase data on this iPhone", so sync pulls the account's copy again.
    @ObservationIgnored var onErase: (() -> Void)?
    /// True while sync applies remote changes, which aren't local edits.
    @ObservationIgnored var isApplyingRemote = false

    @ObservationIgnored private var markerCache: [MarkerCacheKey: [DayKey: DayMarker]] = [:]
    @ObservationIgnored private var markerCacheRevision = 0
    @ObservationIgnored private let logger = Logger(subsystem: "com.devilsense.folio", category: "store")

    struct MarkerCacheKey: Hashable {
        let month: MonthKey
        let firstWeekday: Int
    }

    init(context: ModelContext, calendar: Calendar = .current, now: @escaping () -> Date = { AppClock.now },
         trashClockDefaults: UserDefaults? = nil) {
        self.context = context
        self.calendar = calendar
        self.now = now
        self.trashClockDefaults = trashClockDefaults
    }

    var today: DayKey {
        _ = revision
        return DayKey(date: now(), calendar: calendar)
    }

    // MARK: - Reading

    func entries(on day: DayKey) -> [Entry] {
        _ = revision
        let raw = day.rawValue
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.dayKey == raw && !$0.isTombstone && $0.trashedAt == nil })
        return fetch(descriptor).sorted(by: Self.entryOrder)
    }

    func tasks(on day: DayKey) -> [TaskItem] {
        _ = revision
        let raw: String? = day.rawValue
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.dayKey == raw && !$0.isTombstone && $0.trashedAt == nil })
        return fetch(descriptor).sorted(by: Self.taskOrder)
    }

    func allTasks() -> [TaskItem] {
        _ = revision
        return fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isTombstone && $0.trashedAt == nil })).sorted(by: Self.taskOrder)
    }

    func allEntries() -> [Entry] {
        _ = revision
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { !$0.isTombstone && $0.trashedAt == nil },
            sortBy: [SortDescriptor(\.dayKey, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        return fetch(descriptor)
    }

    /// Every live photo, newest day first, for the Journal's Photos view (SPEC §6.6).
    func allPhotos() -> [EntryPhoto] {
        _ = revision
        return fetch(FetchDescriptor<EntryPhoto>(predicate: #Predicate { !$0.isTombstone }))
            .filter { $0.entry?.isTombstone == false && $0.entry?.trashedAt == nil }
            .sorted { ($0.entry?.dayKey ?? "", $1.sortIndex) > ($1.entry?.dayKey ?? "", $0.sortIndex) }
    }

    func categories() -> [Category] {
        _ = revision
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { !$0.isTombstone && $0.trashedAt == nil }, sortBy: [SortDescriptor(\.sortIndex)])
        return fetch(descriptor)
    }

    func category(id: UUID?) -> Category? {
        guard let id else { return nil }
        return categories().first { $0.id == id }
    }

    func photo(id: UUID) -> EntryPhoto? {
        var descriptor = FetchDescriptor<EntryPhoto>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// Markers for the 42 days shown for `month`. Cached until the next write.
    func markers(for month: MonthKey, firstWeekday: Int) -> [DayKey: DayMarker] {
        _ = revision
        if markerCacheRevision != revision {
            markerCache.removeAll()
            markerCacheRevision = revision
        }
        let key = MarkerCacheKey(month: month, firstWeekday: firstWeekday)
        if let cached = markerCache[key] { return cached }
        let markers = computeMarkers(for: month.gridDays(firstWeekday: firstWeekday))
        markerCache[key] = markers
        return markers
    }

    func computeMarkers(for days: [DayKey]) -> [DayKey: DayMarker] {
        let keys = days.map(\.rawValue)
        let entries = fetch(FetchDescriptor<Entry>(predicate: #Predicate { keys.contains($0.dayKey) && !$0.isTombstone && $0.trashedAt == nil }))
        // `??` inside #Predicate compiles but crashes in SQL generation; compare optionals instead.
        let optionalKeys: [String?] = keys
        let tasks = fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { optionalKeys.contains($0.dayKey) && !$0.isTombstone && $0.trashedAt == nil }))

        var markers: [DayKey: DayMarker] = [:]
        for (raw, dayEntries) in Dictionary(grouping: entries, by: \.dayKey) {
            guard let day = DayKey(rawValue: raw) else { continue }
            var marker = DayMarker()
            let ordered = dayEntries.sorted(by: Self.entryOrder)
            marker.entryCount = ordered.count
            for entry in ordered.reversed() {
                if marker.thumbnailPhotoID == nil, let first = entry.orderedPhotos.first { marker.thumbnailPhotoID = first.id }
            }
            marker.extraEntryCount = marker.thumbnailPhotoID == nil ? 0 : ordered.count - 1
            marker.dotCategoryIDs = Array(ordered.filter { $0.orderedPhotos.isEmpty }.map(\.categoryID).prefix(DayMarker.maximumDots))
            marker.categoryIDs = Set(ordered.compactMap(\.categoryID))
            markers[day] = marker
        }
        for task in tasks {
            guard let day = task.day else { continue }
            var marker = markers[day] ?? DayMarker()
            if task.isCompleted { marker.doneTaskCount += 1 } else { marker.openTaskCount += 1 }
            if let categoryID = task.categoryID { marker.categoryIDs.insert(categoryID) }
            markers[day] = marker
        }
        return markers
    }

    /// The live numbers behind the greeting's summary line (SPEC §4.2).
    func greetingSummary() -> GreetingSummary {
        let today = today
        let todayRaw = today.rawValue
        let open = fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isCompleted && !$0.isTombstone && $0.trashedAt == nil && $0.dayKey != nil }))
        let tasksToday = open.count { $0.dayKey == todayRaw }
        let overdue = open.count { ($0.dayKey ?? todayRaw) < todayRaw }

        let week = (0..<7).map { today.adding(days: -$0).rawValue }
        let pages = fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { week.contains($0.dayKey) && !$0.isTombstone && $0.trashedAt == nil }))

        let earlierYears = (max(today.year - 120, 1)..<today.year).compactMap {
            DayKey(year: $0, month: today.month, day: today.day)?.rawValue
        }
        let onThisDay = fetch(FetchDescriptor<Entry>(predicate: #Predicate { earlierYears.contains($0.dayKey) && !$0.isTombstone && $0.trashedAt == nil }))
            .compactMap(\.day?.year).max()

        return GreetingSummary(tasksToday: tasksToday, tasksOverdue: overdue, pagesThisWeek: pages, onThisDayYear: onThisDay)
    }

    /// Months (1–12) of `year` that have at least one entry, for the Jump sheet dots.
    func monthsWithEntries(in year: Int) -> Set<Int> {
        _ = revision
        let prefix = String(year).count == 4 ? "\(year)-" : String(format: "%04d-", year)
        let entries = fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.dayKey.starts(with: prefix) && !$0.isTombstone && $0.trashedAt == nil }))
        return Set(entries.compactMap { $0.day?.month })
    }

    func usage(of category: Category) -> CategoryUsage {
        let id: UUID? = category.id
        let entries = fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { $0.categoryID == id && !$0.isTombstone && $0.trashedAt == nil }))
        let tasks = fetchCount(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.categoryID == id && !$0.isTombstone && $0.trashedAt == nil }))
        return CategoryUsage(entries: entries, tasks: tasks)
    }

    func settings() -> UserSettings {
        let id = UserSettings.singletonID
        var descriptor = FetchDescriptor<UserSettings>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = fetch(descriptor).first { return existing }
        let created = UserSettings(now: now())
        context.insert(created)
        save()
        return created
    }

    var isEmpty: Bool {
        fetchCount(FetchDescriptor<Entry>()) == 0 && fetchCount(FetchDescriptor<TaskItem>()) == 0
    }

    // MARK: - Entries

    @discardableResult
    func createEntry(title: String = "", body: String = "", day: DayKey, minutesFromMidnight: Int? = nil,
                     categoryID: UUID? = nil) throws(StoreError) -> Entry {
        guard Entry.titleLengths.contains(title.count) else { throw .titleTooLong }
        let entry = Entry(title: title, bodyMarkdown: body, day: day, minutesFromMidnight: minutesFromMidnight,
                          categoryID: categoryID, now: now())
        context.insert(entry)
        commit()
        return entry
    }

    func updateEntry(_ entry: Entry, title: String, body: String, categoryID: UUID?) throws(StoreError) {
        guard Entry.titleLengths.contains(title.count) else { throw .titleTooLong }
        entry.title = title
        entry.bodyMarkdown = body
        entry.categoryID = categoryID
        entry.markChanged(at: now())
        commit()
    }

    /// Moves an entry to another day. Only an explicit move ever changes an item's day.
    func move(_ entry: Entry, to day: DayKey, minutesFromMidnight: Int?) {
        entry.dayKey = day.rawValue
        entry.minutesFromMidnight = minutesFromMidnight
        entry.markChanged(at: now())
        commit()
    }

    @discardableResult
    func addPhoto(_ processed: ProcessedPhoto, to entry: Entry) throws(StoreError) -> EntryPhoto {
        let existing = entry.orderedPhotos
        guard existing.count < Entry.maximumPhotos else { throw .tooManyPhotos }
        let photo = EntryPhoto(entry: entry, sortIndex: (existing.last?.sortIndex ?? -1) + 1, processed: processed, now: now())
        context.insert(photo)
        entry.markChanged(at: now())
        commit()
        return photo
    }

    /// Gives photos stored under schema v1 their 1080 px display rendition, a few at a time
    /// off the main actor. A derived rendition isn't an edit, so `updatedAt` is untouched.
    func backfillDisplayRenditions() async {
        let missing = fetch(FetchDescriptor<EntryPhoto>(predicate: #Predicate { $0.displayData == nil && !$0.isTombstone }))
        guard !missing.isEmpty else { return }
        let processor = PhotoProcessor()
        for photo in missing {
            guard !Task.isCancelled else { break }
            guard let display = try? await processor.displayRendition(of: photo.imageData) else { continue }
            photo.displayData = display
        }
        commit()
    }

    /// Permanent delete: Delete now, Empty, the 30-day purge (SPEC §5.2). Everyday Delete is
    /// `trash(_:)`. Any draft of this entry (and its photo files) goes too.
    func deletePermanently(_ entry: Entry) {
        if drafts.load()?.entryID == entry.id { drafts.clear() }
        for photo in entry.photos { retire(photo) }
        retire(entry)
        commit()
    }

    func delete(_ photo: EntryPhoto) {
        photo.entry?.markChanged(at: now())
        retire(photo)
        commit()
    }

    func entry(id: UUID) -> Entry? {
        _ = revision
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == id && !$0.isTombstone && $0.trashedAt == nil })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// Entries written on the same calendar day in other years (SPEC §6.5 footer).
    func entriesOnSameDay(as day: DayKey, excluding id: UUID) -> [Entry] {
        _ = revision
        let keys = (max(day.year - 120, 1)...(day.year + 10)).compactMap { year -> String? in
            year == day.year ? nil : DayKey(year: year, month: day.month, day: day.day)?.rawValue
        }
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { keys.contains($0.dayKey) && !$0.isTombstone && $0.trashedAt == nil && $0.id != id },
            sortBy: [SortDescriptor(\.dayKey, order: .reverse)]
        )
        return fetch(descriptor)
    }

    /// Applies the composer's photo order; ids not listed keep their relative order after.
    func setPhotoOrder(_ entry: Entry, ids: [UUID]) {
        let photos = entry.orderedPhotos
        let ordered = ids.compactMap { id in photos.first { $0.id == id } } + photos.filter { !ids.contains($0.id) }
        for (index, photo) in ordered.enumerated() where photo.sortIndex != index {
            photo.sortIndex = index
            photo.markChanged(at: now())
        }
        commit()
    }

    /// Everything needed to bring a deleted entry back (Undo, SPEC §6.14).
    struct EntrySnapshot {
        let title: String
        let body: String
        let day: DayKey
        let minutesFromMidnight: Int?
        let categoryID: UUID?
        let photos: [ProcessedPhoto]
    }

    func snapshot(of entry: Entry) -> EntrySnapshot? {
        guard let day = entry.day else { return nil }
        return EntrySnapshot(
            title: entry.title, body: entry.bodyMarkdown, day: day, minutesFromMidnight: entry.minutesFromMidnight,
            categoryID: entry.categoryID,
            photos: entry.orderedPhotos.map {
                ProcessedPhoto(imageData: $0.imageData, thumbnailData: $0.thumbData, pixelWidth: $0.pixelWidth,
                               pixelHeight: $0.pixelHeight, imageType: "public.heic", displayData: $0.displayData ?? Data())
            }
        )
    }

    @discardableResult
    func restore(_ snapshot: EntrySnapshot) -> Entry? {
        guard let entry = try? createEntry(title: snapshot.title, body: snapshot.body, day: snapshot.day,
                                           minutesFromMidnight: snapshot.minutesFromMidnight,
                                           categoryID: category(id: snapshot.categoryID)?.id) else { return nil }
        for photo in snapshot.photos { _ = try? addPhoto(photo, to: entry) }
        return entry
    }

    @discardableResult
    func duplicate(_ entry: Entry) -> Entry? {
        snapshot(of: entry).flatMap(restore)
    }

    // MARK: - Tasks

    @discardableResult
    func createTask(title: String, notes: String? = nil, day: DayKey? = nil, minutesFromMidnight: Int? = nil,
                    categoryID: UUID? = nil) throws(StoreError) -> TaskItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .taskTitleEmpty }
        guard TaskItem.titleLengths.contains(trimmed.count) else { throw .titleTooLong }
        guard (notes?.count ?? 0) <= TaskItem.maximumNotesLength else { throw .notesTooLong }
        let nextIndex = (allTasks().map(\.sortIndex).max() ?? -1) + 1
        let task = TaskItem(title: trimmed, notes: notes, day: day, minutesFromMidnight: minutesFromMidnight,
                            categoryID: categoryID, sortIndex: nextIndex, now: now())
        context.insert(task)
        commit()
        return task
    }

    /// Completing keeps the task on its day, shown as done (SPEC §5).
    func setCompleted(_ task: TaskItem, _ completed: Bool) {
        task.isCompleted = completed
        task.completedAt = completed ? now() : nil
        task.markChanged(at: now())
        commit()
    }

    func reschedule(_ task: TaskItem, to day: DayKey?, minutesFromMidnight: Int? = nil) {
        task.dayKey = day?.rawValue
        task.minutesFromMidnight = day == nil ? nil : minutesFromMidnight
        task.markChanged(at: now())
        commit()
    }

    func updateTask(_ task: TaskItem, title: String, notes: String?, day: DayKey?, minutesFromMidnight: Int?,
                    categoryID: UUID?) throws(StoreError) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .taskTitleEmpty }
        guard TaskItem.titleLengths.contains(trimmed.count) else { throw .titleTooLong }
        guard (notes?.count ?? 0) <= TaskItem.maximumNotesLength else { throw .notesTooLong }
        task.title = trimmed
        task.notes = notes?.isEmpty == true ? nil : notes
        task.dayKey = day?.rawValue
        task.minutesFromMidnight = day == nil ? nil : minutesFromMidnight
        task.categoryID = categoryID
        task.markChanged(at: now())
        commit()
    }

    /// Drag order for undated tasks (SPEC §6.7).
    func reorderTasks(_ ordered: [TaskItem]) {
        let indices = ordered.map(\.sortIndex).sorted()
        for (task, index) in zip(ordered, indices) where task.sortIndex != index {
            task.sortIndex = index
            task.markChanged(at: now())
        }
        commit()
    }

    func task(id: UUID) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id && !$0.isTombstone && $0.trashedAt == nil })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// Permanent delete (SPEC §5.2); everyday Delete is `trash(_:)`.
    func deletePermanently(_ task: TaskItem) {
        retire(task)
        commit()
    }

    // MARK: - Categories

    @discardableResult
    func createCategory(name: String, color: CategoryColor, symbol: String? = nil) throws(StoreError) -> Category {
        let existing = categories()
        guard existing.count < Category.maximumCount else { throw .tooManyCategories }
        let cleaned = try validatedCategoryName(name, ignoring: nil)
        let category = Category(name: cleaned, color: color, symbol: symbol,
                                sortIndex: (existing.last?.sortIndex ?? -1) + 1, now: now())
        context.insert(category)
        commit()
        return category
    }

    func updateCategory(_ category: Category, name: String, color: CategoryColor, symbol: String?) throws(StoreError) {
        category.name = try validatedCategoryName(name, ignoring: category.id)
        category.colorKey = color.rawValue
        category.symbol = symbol
        category.markChanged(at: now())
        commit()
    }

    func reorderCategories(_ ordered: [Category]) {
        for (index, category) in ordered.enumerated() where category.sortIndex != index {
            category.sortIndex = index
            category.markChanged(at: now())
        }
        commit()
    }

    /// Permanent delete (SPEC §5.2). Its entries and tasks were already un-assigned when it
    /// went to Recently Deleted (`trash(_:)`); this also covers a live one, for safety.
    func deletePermanently(_ category: Category) {
        if category.trashedAt == nil { unassign(category, at: now()) }
        retire(category)
        commit()
    }

    /// Takes every entry and task (live or trashed) off a category and returns their ids.
    /// Deleting a category never deletes its items (SPEC §5).
    @discardableResult
    func unassign(_ category: Category, at stamp: Date) -> [UUID] {
        let id: UUID? = category.id
        var ids: [UUID] = []
        for entry in fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.categoryID == id && !$0.isTombstone })) {
            entry.categoryID = nil
            entry.markChanged(at: stamp)
            ids.append(entry.id)
        }
        for task in fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.categoryID == id && !$0.isTombstone })) {
            task.categoryID = nil
            task.markChanged(at: stamp)
            ids.append(task.id)
        }
        let settings = settings()
        if settings.defaultCategoryID == category.id {
            settings.defaultCategoryID = nil
            settings.markChanged(at: stamp)
        }
        return ids
    }

    private func validatedCategoryName(_ name: String, ignoring id: UUID?) throws(StoreError) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw .categoryNameEmpty }
        guard Category.nameLengths.contains(cleaned.count) else { throw .categoryNameTooLong }
        let clash = categories().contains {
            $0.id != id && $0.name.compare(cleaned, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !clash else { throw .duplicateCategoryName }
        return cleaned
    }

    // MARK: - Settings

    func updateSettings(_ change: (UserSettings) -> Void) {
        let settings = settings()
        change(settings)
        settings.markChanged(at: now())
        commit()
    }

    // MARK: - Erase

    /// "Erase data on this iPhone" (SPEC §6.9): removes every local record.
    func eraseAll() {
        // Not `context.delete(model:)`: SwiftData's batch delete fails on the Entry → EntryPhoto
        // inverse ("mandatory OTO nullify inverse") and silently leaves everything in place.
        // Deleting objects lets the cascade rule remove photos with their entries.
        for entry in fetch(FetchDescriptor<Entry>()) { context.delete(entry) }
        for photo in fetch(FetchDescriptor<EntryPhoto>()) { context.delete(photo) }
        for task in fetch(FetchDescriptor<TaskItem>()) { context.delete(task) }
        for category in fetch(FetchDescriptor<Category>()) { context.delete(category) }
        for settings in fetch(FetchDescriptor<UserSettings>()) { context.delete(settings) }
        commit()
        ThumbnailCache.shared.removeAll()
        DisplayImageCache.shared.removeAll()
        // A draft (and its photos) is diary content too.
        drafts.clear()
        onErase?()
    }

    // MARK: - Helpers

    /// Never-synced records are deleted outright; synced ones become tombstones until the
    /// server acknowledges the deletion (SPEC §5).
    func retire(_ record: some SyncedRecord & PersistentModel) {
        if record.serverVersion == nil {
            context.delete(record)
        } else {
            record.isTombstone = true
            record.markChanged(at: now())
        }
    }

    func commit() {
        save()
        revision += 1
        if !isApplyingRemote { onLocalChange?() }
    }

    func save() {
        do {
            try context.save()
        } catch {
            // Never log content; the error type is enough to diagnose.
            logger.error("Save failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetch failed: \(String(describing: type(of: error)), privacy: .public)")
            return []
        }
    }

    func fetchCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> Int {
        (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Timed entries by time, then untimed, each in creation order.
    static func entryOrder(_ a: Entry, _ b: Entry) -> Bool {
        switch (a.minutesFromMidnight, b.minutesFromMidnight) {
        case let (x?, y?) where x != y: x < y
        case (.some, nil): true
        case (nil, .some): false
        default: a.createdAt < b.createdAt
        }
    }

    /// Open before done; then by time, then manual order.
    static func taskOrder(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.isCompleted != b.isCompleted { return !a.isCompleted }
        switch (a.minutesFromMidnight, b.minutesFromMidnight) {
        case let (x?, y?) where x != y: return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        default: return a.sortIndex < b.sortIndex
        }
    }
}
