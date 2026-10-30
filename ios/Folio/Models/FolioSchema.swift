import Foundation
import SwiftData

/// Schema version 1, frozen as it shipped in Phase 2. Only the models that changed since are
/// copied here; unchanged models are shared with the current schema (swiftdata-pro: always
/// have a migration plan).
enum FolioSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [FolioSchemaV2.Category.self, Entry.self, EntryPhoto.self, FolioSchemaV2.TaskItem.self, FolioSchemaV3.UserSettings.self]
    }

    @Model nonisolated
    final class Entry {
        #Unique<Entry>([\.id])
        #Index<Entry>([\.dayKey], [\.isTombstone, \.dayKey])

        var id: UUID
        var title: String
        var bodyMarkdown: String
        var dayKey: String
        var minutesFromMidnight: Int?
        var categoryID: UUID?
        @Relationship(deleteRule: .cascade, inverse: \EntryPhoto.entry)
        var photos: [EntryPhoto] = []
        var createdAt: Date
        var updatedAt: Date
        var serverVersion: Int64?
        var isDirty: Bool
        var isTombstone: Bool

        init(id: UUID, title: String, bodyMarkdown: String, dayKey: String, now: Date) {
            self.id = id
            self.title = title
            self.bodyMarkdown = bodyMarkdown
            self.dayKey = dayKey
            self.createdAt = now
            self.updatedAt = now
            self.isDirty = true
            self.isTombstone = false
        }
    }

    @Model nonisolated
    final class EntryPhoto {
        #Unique<EntryPhoto>([\.id])

        var id: UUID
        var entryID: UUID
        var entry: Entry?
        var sortIndex: Int
        @Attribute(.externalStorage) var imageData: Data
        @Attribute(.externalStorage) var thumbData: Data
        var pixelWidth: Int
        var pixelHeight: Int
        var blobUploaded: Bool
        var createdAt: Date
        var updatedAt: Date
        var serverVersion: Int64?
        var isDirty: Bool
        var isTombstone: Bool

        init(id: UUID, entryID: UUID, now: Date) {
            self.id = id
            self.entryID = entryID
            self.sortIndex = 0
            self.imageData = Data()
            self.thumbData = Data()
            self.pixelWidth = 0
            self.pixelHeight = 0
            self.blobUploaded = false
            self.createdAt = now
            self.updatedAt = now
            self.isDirty = true
            self.isTombstone = false
        }
    }
}

/// Schema version 2 (Batch C): `EntryPhoto.displayData`, the 1080 px display rendition.
/// Its frozen models are in `FolioSchemaV2Models.swift`.
enum FolioSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [FolioSchemaV2.Category.self, FolioSchemaV2.Entry.self, FolioSchemaV2.EntryPhoto.self,
         FolioSchemaV2.TaskItem.self, FolioSchemaV3.UserSettings.self]
    }
}

/// Schema version 3 (Batch D, SPEC §5.2): `trashedAt` on Entry, TaskItem and Category, and
/// `Category.unassignedIDs`, for Recently Deleted. Its frozen TaskItem and UserSettings are in
/// `FolioSchemaV3Models.swift`.
enum FolioSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Category.self, Entry.self, EntryPhoto.self, FolioSchemaV3.TaskItem.self, FolioSchemaV3.UserSettings.self]
    }
}

/// Schema version 4 (Batch I): `TaskItem.remindAt`, `repeatRule`, `parentID`;
/// `UserSettings.avatar`, `avatarPhoto`. These are the live models.
enum FolioSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Category.self, Entry.self, EntryPhoto.self, TaskItem.self, UserSettings.self]
    }
}

enum FolioMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FolioSchemaV1.self, FolioSchemaV2.self, FolioSchemaV3.self, FolioSchemaV4.self] }

    /// Each step only adds optional attributes, so all are lightweight. Renditions are
    /// backfilled after launch rather than inside the migration, so opening the store stays fast.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: FolioSchemaV1.self, toVersion: FolioSchemaV2.self),
         .lightweight(fromVersion: FolioSchemaV2.self, toVersion: FolioSchemaV3.self),
         .lightweight(fromVersion: FolioSchemaV3.self, toVersion: FolioSchemaV4.self)]
    }
}
