import FolioCrypto
import Foundation
import SwiftData

/// What the sync engine needs from the store (SPEC §10.5): dirty records and their payloads
/// out, remote records in. Remote changes never count as local edits (`isApplyingRemote`).
extension DiaryStore {
    typealias SyncModel = any SyncedRecord & PersistentModel

    // MARK: Out

    /// Every record with a local change, in an order whose references resolve on the other
    /// side: categories and settings, entries, photos, tasks.
    func dirtyRecords() -> [SyncModel] {
        var records: [SyncModel] = []
        records += fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.isDirty })) as [SyncModel]
        records += fetch(FetchDescriptor<UserSettings>(predicate: #Predicate { $0.isDirty })) as [SyncModel]
        records += fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.isDirty })) as [SyncModel]
        records += fetch(FetchDescriptor<EntryPhoto>(predicate: #Predicate { $0.isDirty })) as [SyncModel]
        records += fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isDirty })) as [SyncModel]
        return records
    }

    var hasDirtyRecords: Bool {
        fetchCount(FetchDescriptor<Category>(predicate: #Predicate { $0.isDirty }))
            + fetchCount(FetchDescriptor<UserSettings>(predicate: #Predicate { $0.isDirty }))
            + fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { $0.isDirty }))
            + fetchCount(FetchDescriptor<EntryPhoto>(predicate: #Predicate { $0.isDirty }))
            + fetchCount(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isDirty })) > 0
    }

    /// The JSON that gets encrypted for this record.
    func payload(of record: SyncModel) throws -> Data {
        let encoder = RecordPayload.encoder
        switch record {
        case let entry as Entry:
            return try encoder.encode(RecordPayload.Entry(
                title: entry.title, bodyMarkdown: entry.bodyMarkdown, dayKey: entry.dayKey, minutesFromMidnight: entry.minutesFromMidnight,
                categoryID: entry.categoryID, createdAt: entry.createdAt, trashedAt: entry.trashedAt))
        case let photo as EntryPhoto:
            return try encoder.encode(RecordPayload.EntryPhoto(
                entryID: photo.entryID, sortIndex: photo.sortIndex, pixelWidth: photo.pixelWidth, pixelHeight: photo.pixelHeight,
                createdAt: photo.createdAt))
        case let task as TaskItem:
            return try encoder.encode(RecordPayload.Task(
                title: task.title, notes: task.notes, dayKey: task.dayKey, minutesFromMidnight: task.minutesFromMidnight,
                categoryID: task.categoryID, isCompleted: task.isCompleted, completedAt: task.completedAt, sortIndex: task.sortIndex,
                createdAt: task.createdAt, trashedAt: task.trashedAt, remindAt: task.remindAt, repeatRule: task.repeatRule,
                parentID: task.parentID))
        case let category as Category:
            return try encoder.encode(RecordPayload.Category(
                name: category.name, colorKey: category.colorKey, symbol: category.symbol, sortIndex: category.sortIndex,
                createdAt: category.createdAt, trashedAt: category.trashedAt, unassignedIDs: category.unassignedIDs))
        case let settings as UserSettings:
            return try encoder.encode(RecordPayload.Settings(
                displayName: settings.displayName, appearance: settings.appearance, writingFont: settings.writingFont,
                firstWeekday: settings.firstWeekday, defaultCategoryID: settings.defaultCategoryID, createdAt: settings.createdAt,
                avatar: settings.avatar, avatarPhoto: settings.avatarPhoto))
        default:
            throw CocoaError(.coderInvalidValue)
        }
    }

    /// The server accepted this push. A record edited again since it was read stays dirty.
    func markSynced(_ record: SyncModel, version: Int64, sentUpdatedAt: Int64) {
        record.serverVersion = version
        guard record.updatedAt.millisecondsSince1970 == sentUpdatedAt else { return }
        record.isDirty = false
        if record.isTombstone { context.delete(record) }
    }

    // MARK: In

    /// Applies one record from the server. Last writer wins by `updatedAt`: a local edit that's
    /// newer stays (and will push); a tombstone always wins and is never recreated.
    func applyRemote(_ remote: SyncWire.Remote, type: RecordType, plaintext: Data?) {
        let local = syncedRecord(id: remote.id, type: type)
        if remote.deleted {
            if let local { context.delete(local) }
            return
        }
        if let local, local.isDirty, local.updatedAt.millisecondsSince1970 > remote.clientUpdatedAt {
            local.serverVersion = remote.version
            return
        }
        guard let plaintext else { return }
        let decoder = RecordPayload.decoder
        let stamp = Date(millisecondsSince1970: remote.clientUpdatedAt)
        let record: SyncModel?
        switch type {
        case .entry: record = (try? decoder.decode(RecordPayload.Entry.self, from: plaintext)).map { upsertEntry($0, id: remote.id, local: local as? Entry) }
        case .entryPhoto: record = (try? decoder.decode(RecordPayload.EntryPhoto.self, from: plaintext)).map { upsertPhoto($0, id: remote.id, stamp: stamp, local: local as? EntryPhoto) }
        case .task: record = (try? decoder.decode(RecordPayload.Task.self, from: plaintext)).map { upsertTask($0, id: remote.id, local: local as? TaskItem) }
        case .category: record = (try? decoder.decode(RecordPayload.Category.self, from: plaintext)).map { upsertCategory($0, id: remote.id, local: local as? Category) }
        case .settings: record = (try? decoder.decode(RecordPayload.Settings.self, from: plaintext)).map { upsertSettings($0, local: local as? UserSettings) }
        default: record = nil
        }
        guard let record else { return }
        record.updatedAt = stamp
        record.serverVersion = remote.version
        record.isDirty = false
        record.isTombstone = false
    }

    /// Photos can arrive before their entry (the entry changed later, so it's on a later page).
    func linkOrphanPhotos() {
        for photo in fetch(FetchDescriptor<EntryPhoto>(predicate: #Predicate { $0.entry == nil })) {
            photo.entry = syncedRecord(id: photo.entryID, type: .entry) as? Entry
        }
    }

    func syncedRecord(id: UUID, type: RecordType) -> SyncModel? {
        switch type {
        case .entry: one(#Predicate<Entry> { $0.id == id })
        case .entryPhoto: one(#Predicate<EntryPhoto> { $0.id == id })
        case .task: one(#Predicate<TaskItem> { $0.id == id })
        case .category: one(#Predicate<Category> { $0.id == id })
        case .settings: one(#Predicate<UserSettings> { $0.id == id })
        default: nil
        }
    }

    /// Photos whose bytes haven't downloaded yet, thumbnails' owners first by day.
    func photosNeedingDownload() -> [EntryPhoto] {
        fetch(FetchDescriptor<EntryPhoto>(predicate: #Predicate { !$0.isTombstone && $0.blobUploaded }))
            .filter(\.needsDownload)
    }

    func photosNeedingUpload() -> [EntryPhoto] {
        fetch(FetchDescriptor<EntryPhoto>(predicate: #Predicate { !$0.isTombstone && !$0.blobUploaded }))
    }

    // MARK: Accounts

    /// Joining an account that already exists: this device's never-synced settings are older
    /// than the account's, so the account's name, theme and font win (DECISIONS 184).
    func letAccountSettingsWin() {
        let settings = settings()
        guard settings.serverVersion == nil else { return }
        settings.updatedAt = Date(timeIntervalSince1970: 0)
        save()
    }

    /// Signed out or account deleted, keeping the diary (SPEC §10.5–10.6): back to a guest
    /// store whose records are all unsynced again, so a later sign-in pushes them.
    func detachFromAccount() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        func reset(_ record: SyncModel) {
            if record.isTombstone { context.delete(record); return }
            record.serverVersion = nil
            record.isDirty = true
        }
        fetch(FetchDescriptor<Category>()).forEach { reset($0) }
        fetch(FetchDescriptor<UserSettings>()).forEach { reset($0) }
        fetch(FetchDescriptor<Entry>()).forEach { reset($0) }
        fetch(FetchDescriptor<TaskItem>()).forEach { reset($0) }
        for photo in fetch(FetchDescriptor<EntryPhoto>()) {
            // A photo whose bytes never arrived can't be kept.
            if photo.imageData.isEmpty && photo.thumbData.isEmpty { context.delete(photo); continue }
            reset(photo)
            photo.blobUploaded = false
        }
        commit()
    }

    // MARK: Upserts

    private func one<T: PersistentModel>(_ predicate: Predicate<T>) -> T? {
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    private func upsertEntry(_ p: RecordPayload.Entry, id: UUID, local: Entry?) -> Entry {
        let entry = local ?? {
            let created = Entry(id: id, title: p.title, bodyMarkdown: p.bodyMarkdown, day: DayKey(rawValue: p.dayKey) ?? today, now: p.createdAt)
            context.insert(created)
            return created
        }()
        entry.title = p.title
        entry.bodyMarkdown = p.bodyMarkdown
        entry.dayKey = p.dayKey
        entry.minutesFromMidnight = p.minutesFromMidnight
        entry.categoryID = p.categoryID
        entry.createdAt = p.createdAt
        entry.trashedAt = p.trashedAt
        return entry
    }

    private func upsertPhoto(_ p: RecordPayload.EntryPhoto, id: UUID, stamp: Date, local: EntryPhoto?) -> EntryPhoto {
        let photo = local ?? {
            let created = EntryPhoto(id: id, entryID: p.entryID, sortIndex: p.sortIndex, pixelWidth: p.pixelWidth,
                                     pixelHeight: p.pixelHeight, createdAt: p.createdAt, updatedAt: stamp)
            context.insert(created)
            return created
        }()
        photo.entryID = p.entryID
        photo.sortIndex = p.sortIndex
        photo.pixelWidth = p.pixelWidth
        photo.pixelHeight = p.pixelHeight
        if photo.entry?.id != p.entryID { photo.entry = syncedRecord(id: p.entryID, type: .entry) as? Entry }
        return photo
    }

    private func upsertTask(_ p: RecordPayload.Task, id: UUID, local: TaskItem?) -> TaskItem {
        let task = local ?? {
            let created = TaskItem(id: id, title: p.title, sortIndex: p.sortIndex, now: p.createdAt)
            context.insert(created)
            return created
        }()
        task.title = p.title
        task.notes = p.notes
        task.dayKey = p.dayKey
        task.minutesFromMidnight = p.minutesFromMidnight
        task.categoryID = p.categoryID
        task.isCompleted = p.isCompleted
        task.completedAt = p.completedAt
        task.sortIndex = p.sortIndex
        task.createdAt = p.createdAt
        task.trashedAt = p.trashedAt
        task.remindAt = p.remindAt
        task.repeatRule = p.repeatRule
        task.parentID = p.parentID
        return task
    }

    private func upsertCategory(_ p: RecordPayload.Category, id: UUID, local: Category?) -> Category {
        let category = local ?? {
            let created = Category(id: id, name: p.name, color: CategoryColor(key: p.colorKey), sortIndex: p.sortIndex, now: p.createdAt)
            context.insert(created)
            return created
        }()
        category.name = p.name
        category.colorKey = p.colorKey
        category.symbol = p.symbol
        category.sortIndex = p.sortIndex
        category.createdAt = p.createdAt
        category.trashedAt = p.trashedAt
        category.unassignedIDs = p.unassignedIDs
        return category
    }

    private func upsertSettings(_ p: RecordPayload.Settings, local: UserSettings?) -> UserSettings {
        let settings = local ?? settings()
        settings.displayName = p.displayName
        settings.appearance = p.appearance
        settings.writingFont = p.writingFont
        settings.firstWeekday = p.firstWeekday
        settings.defaultCategoryID = p.defaultCategoryID
        settings.createdAt = p.createdAt
        settings.avatar = p.avatar
        settings.avatarPhoto = p.avatarPhoto
        return settings
    }
}
