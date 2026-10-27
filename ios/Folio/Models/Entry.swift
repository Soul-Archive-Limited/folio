import Foundation
import FolioCrypto
import SwiftData

/// A diary entry for one floating day (SPEC §5).
@Model nonisolated
final class Entry: TrashableRecord {
    #Unique<Entry>([\.id])
    #Index<Entry>([\.dayKey], [\.isTombstone, \.dayKey])

    static let recordType: RecordType = .entry
    static let titleLengths = 0...120
    static let maximumPhotos = 10

    var id: UUID
    var title: String
    var bodyMarkdown: String
    /// `DayKey.rawValue`, e.g. "2026-10-14".
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
    /// When it was moved to Recently Deleted (SPEC §5.2); nil while live. Added in schema v3.
    var trashedAt: Date?

    init(id: UUID = UUID(), title: String, bodyMarkdown: String, day: DayKey, minutesFromMidnight: Int? = nil,
         categoryID: UUID? = nil, now: Date) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.dayKey = day.rawValue
        self.minutesFromMidnight = minutesFromMidnight
        self.categoryID = categoryID
        self.createdAt = now
        self.updatedAt = now
        self.serverVersion = nil
        self.isDirty = true
        self.isTombstone = false
    }

    var day: DayKey? { DayKey(rawValue: dayKey) }

    /// Live photos in display order.
    var orderedPhotos: [EntryPhoto] {
        photos.filter { !$0.isTombstone }.sorted { $0.sortIndex < $1.sortIndex }
    }
}
