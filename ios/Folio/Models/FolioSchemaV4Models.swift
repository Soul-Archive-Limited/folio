import Foundation
import SwiftData

/// Schema v4's Entry and EntryPhoto, frozen when v5 added `Entry.mood` (Batch J). EntryPhoto is
/// unchanged but frozen with it, since the two are linked by their relationship. Schema v3 had
/// the same two models, so it uses these too.
extension FolioSchemaV4 {
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
        var trashedAt: Date?

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
}
