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

    private(set) var revision = 0

    @ObservationIgnored private var markerCache: [MarkerCacheKey: [DayKey: DayMarker]] = [:]
    @ObservationIgnored private var markerCacheRevision = 0
    @ObservationIgnored private let logger = Logger(subsystem: "com.devilsense.folio", category: "store")

    struct MarkerCacheKey: Hashable {
        let month: MonthKey
        let firstWeekday: Int
    }

    init(context: ModelContext, calendar: Calendar = .current, now: @escaping () -> Date = { AppClock.now }) {
        self.context = context
        self.calendar = calendar
        self.now = now
    }

    var today: DayKey {
        _ = revision
        return DayKey(date: now(), calendar: calendar)
    }

    // MARK: - Reading

    func entries(on day: DayKey) -> [Entry] {
        _ = revision
        let raw = day.rawValue
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.dayKey == raw && !$0.isTombstone })
        return fetch(descriptor).sorted(by: Self.entryOrder)
    }

    func tasks(on day: DayKey) -> [TaskItem] {
        _ = revision
        let raw: String? = day.rawValue
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.dayKey == raw && !$0.isTombstone })
        return fetch(descriptor).sorted(by: Self.taskOrder)
    }

    func allTasks() -> [TaskItem] {
        _ = revision
        return fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isTombstone })).sorted(by: Self.taskOrder)
    }

    func allEntries() -> [Entry] {
        _ = revision
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { !$0.isTombstone },
            sortBy: [SortDescriptor(\.dayKey, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        return fetch(descriptor)
    }

    func categories() -> [Category] {
        _ = revision
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { !$0.isTombstone }, sortBy: [SortDescriptor(\.sortIndex)])
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
        let entries = fetch(FetchDescriptor<Entry>(predicate: #Predicate { keys.contains($0.dayKey) && !$0.isTombstone }))
        // `??` inside #Predicate compiles but crashes in SQL generation; compare optionals instead.
        let optionalKeys: [String?] = keys
        let tasks = fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { optionalKeys.contains($0.dayKey) && !$0.isTombstone }))

        var markers: [DayKey: DayMarker] = [:]
        for (raw, dayEntries) in Dictionary(grouping: entries, by: \.dayKey) {
            guard let day = DayKey(rawValue: raw) else { continue }
            var marker = DayMarker()
            let ordered = dayEntries.sorted(by: Self.entryOrder)
            marker.entryCount = ordered.count
            var photoCount = 0
            for entry in ordered.reversed() {
                let photos = entry.orderedPhotos
                photoCount += photos.count
                if marker.thumbnailPhotoID == nil, let first = photos.first { marker.thumbnailPhotoID = first.id }
            }
            marker.extraPhotoCount = max(photoCount - 1, 0)
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
        let open = fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isCompleted && !$0.isTombstone && $0.dayKey != nil }))
        let tasksToday = open.count { $0.dayKey == todayRaw }
        let overdue = open.count { ($0.dayKey ?? todayRaw) < todayRaw }

        let week = (0..<7).map { today.adding(days: -$0).rawValue }
        let pages = fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { week.contains($0.dayKey) && !$0.isTombstone }))

        let earlierYears = (max(today.year - 120, 1)..<today.year).compactMap {
            DayKey(year: $0, month: today.month, day: today.day)?.rawValue
        }
        let onThisDay = fetch(FetchDescriptor<Entry>(predicate: #Predicate { earlierYears.contains($0.dayKey) && !$0.isTombstone }))
            .compactMap(\.day?.year).max()

        return GreetingSummary(tasksToday: tasksToday, tasksOverdue: overdue, pagesThisWeek: pages, onThisDayYear: onThisDay)
    }

    func usage(of category: Category) -> CategoryUsage {
        let id: UUID? = category.id
        let entries = fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { $0.categoryID == id && !$0.isTombstone }))
        let tasks = fetchCount(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.categoryID == id && !$0.isTombstone }))
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

    /// Deleting is the only way an item leaves the calendar (SPEC §5).
    func delete(_ entry: Entry) {
        for photo in entry.photos { retire(photo) }
        retire(entry)
        commit()
    }

    func delete(_ photo: EntryPhoto) {
        photo.entry?.markChanged(at: now())
        retire(photo)
        commit()
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

    func delete(_ task: TaskItem) {
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

    /// Deleting a category un-assigns its entries and tasks; it never deletes them (SPEC §5).
    func delete(_ category: Category) {
        let id: UUID? = category.id
        let stamp = now()
        for entry in fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.categoryID == id })) {
            entry.categoryID = nil
            entry.markChanged(at: stamp)
        }
        for task in fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.categoryID == id })) {
            task.categoryID = nil
            task.markChanged(at: stamp)
        }
        let settings = settings()
        if settings.defaultCategoryID == category.id {
            settings.defaultCategoryID = nil
            settings.markChanged(at: stamp)
        }
        retire(category)
        commit()
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
        do {
            try context.delete(model: EntryPhoto.self)
            try context.delete(model: Entry.self)
            try context.delete(model: TaskItem.self)
            try context.delete(model: Category.self)
            try context.delete(model: UserSettings.self)
        } catch {
            logger.error("Erase failed: \(error.localizedDescription, privacy: .public)")
        }
        commit()
    }

    // MARK: - Helpers

    /// Never-synced records are deleted outright; synced ones become tombstones until the
    /// server acknowledges the deletion (SPEC §5).
    private func retire(_ record: some SyncedRecord & PersistentModel) {
        if record.serverVersion == nil {
            context.delete(record)
        } else {
            record.isTombstone = true
            record.markChanged(at: now())
        }
    }

    private func commit() {
        save()
        revision += 1
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // Never log content; the error type is enough to diagnose.
            logger.error("Save failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetch failed: \(String(describing: type(of: error)), privacy: .public)")
            return []
        }
    }

    private func fetchCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> Int {
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
