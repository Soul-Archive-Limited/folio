import Foundation
import FolioCrypto
import SwiftData

/// A photo attached to an entry (SPEC §5). Image bytes live in external storage, in three
/// renditions: full (`imageData`), display (1080 px) and thumbnail (240 px).
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
    /// Added in schema v2. Optional so the migration is lightweight; photos from v1 get it
    /// from `DiaryStore.backfillDisplayRenditions()`.
    @Attribute(.externalStorage) var displayData: Data?
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
        self.displayData = processed.displayData.isEmpty ? nil : processed.displayData
        self.pixelWidth = processed.pixelWidth
        self.pixelHeight = processed.pixelHeight
        self.blobUploaded = false
        self.createdAt = now
        self.updatedAt = now
        self.serverVersion = nil
        self.isDirty = true
        self.isTombstone = false
    }

    /// A photo that arrived from another device (Phase 10): metadata first, image bytes once its
    /// encrypted blobs download. Empty data means "not downloaded yet".
    init(id: UUID, entryID: UUID, sortIndex: Int, pixelWidth: Int, pixelHeight: Int, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.entryID = entryID
        self.entry = nil
        self.sortIndex = sortIndex
        self.imageData = Data()
        self.thumbData = Data()
        self.displayData = nil
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.blobUploaded = true
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverVersion = nil
        self.isDirty = false
        self.isTombstone = false
    }

    /// Bytes still to download from R2.
    var needsDownload: Bool { thumbData.isEmpty || imageData.isEmpty || displayData == nil }

    /// The display rendition, or the full image for a photo the backfill hasn't reached yet.
    var displayOrFullData: Data { displayData ?? imageData }
}
