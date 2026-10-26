import Foundation
import FolioCrypto
import SwiftData

/// A photo attached to an entry (SPEC §5). Image bytes live in external storage.
@Model nonisolated
final class EntryPhoto: SyncedRecord {
    #Unique<EntryPhoto>([\.id])

    static let recordType: RecordType = .entryPhoto

    var id: UUID
    /// Kept alongside the relationship because it's part of the synced payload.
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

    init(id: UUID = UUID(), entry: Entry, sortIndex: Int, processed: ProcessedPhoto, now: Date) {
        self.id = id
        self.entryID = entry.id
        self.entry = entry
        self.sortIndex = sortIndex
        self.imageData = processed.imageData
        self.thumbData = processed.thumbnailData
        self.pixelWidth = processed.pixelWidth
        self.pixelHeight = processed.pixelHeight
        self.blobUploaded = false
        self.createdAt = now
        self.updatedAt = now
        self.serverVersion = nil
        self.isDirty = true
        self.isTombstone = false
    }
}
