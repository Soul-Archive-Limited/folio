import Foundation
import SwiftData

/// Schema version 2, frozen as it shipped in Batch C. Entry, EntryPhoto, TaskItem and
/// Category changed in v3 (Recently Deleted), so their v2 shapes are copied here. Category
/// and TaskItem were unchanged between v1 and v2, so v1 uses these copies too.
extension FolioSchemaV2 {
    @Model nonisolated
    final class Category {
        #Unique<Category>([\.id])

        var id: UUID
        var name: String
        var colorKey: String
        var symbol: String?
        var sortIndex: Int
        var createdAt: Date
        var updatedAt: Date
        var serverVersion: Int64?
        var isDirty: Bool
        var isTombstone: Bool

        init(id: UUID, name: String, colorKey: String, sortIndex: Int, now: Date) {
            self.id = id
            self.name = name
            self.colorKey = colorKey
            self.sortIndex = sortIndex
            self.createdAt = now
            self.updatedAt = now
            self.isDirty = true
            self.isTombstone = false
        }
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

        init(id: UUID, title: String, bodyMarkdown: String, dayKey: String, categoryID: UUID?, now: Date) {
            self.id = id
            self.title = title
            self.bodyMarkdown = bodyMarkdown
            self.dayKey = dayKey
            self.categoryID = categoryID
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
        @Attribute(.externalStorage) var displayData: Data?
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

    @Model nonisolated
    final class TaskItem {
        #Unique<TaskItem>([\.id])
        #Index<TaskItem>([\.dayKey], [\.isTombstone, \.isCompleted])

        var id: UUID
        var title: String
        var notes: String?
        var dayKey: String?
        var minutesFromMidnight: Int?
        var categoryID: UUID?
        var isCompleted: Bool
        var completedAt: Date?
        var sortIndex: Int
        var createdAt: Date
        var updatedAt: Date
        var serverVersion: Int64?
        var isDirty: Bool
        var isTombstone: Bool

        init(id: UUID, title: String, dayKey: String?, sortIndex: Int, now: Date) {
            self.id = id
            self.title = title
            self.dayKey = dayKey
            self.isCompleted = false
            self.sortIndex = sortIndex
            self.createdAt = now
            self.updatedAt = now
            self.isDirty = true
            self.isTombstone = false
        }
    }
}
