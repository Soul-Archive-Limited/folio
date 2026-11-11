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
    /// How the day felt, 1 (heavy) … 5 (bright); nil = not set. Added in schema v5 (Batch J).
    var mood: Int?
    /// Where it was written (Batch N, schema v6): see `place`. All nil = no place.
    var placeName: String?
    var placeAddress: String?
    var placeLatitude: Double?
    var placeLongitude: Double?

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

    /// The entry's place, stored as four optional attributes so the migration is lightweight
    /// and the Places map can read coordinates without decoding anything.
    var place: Place? {
        get {
            guard let placeName else { return nil }
            return Place(name: placeName, address: placeAddress, latitude: placeLatitude, longitude: placeLongitude)
        }
        set {
            let clean = newValue?.validated()
            placeName = clean?.name
            placeAddress = clean?.address
            placeLatitude = clean?.latitude
            placeLongitude = clean?.longitude
        }
    }

    /// Live photos in display order.
    var orderedPhotos: [EntryPhoto] {
        photos.filter { !$0.isTombstone }.sorted { $0.sortIndex < $1.sortIndex }
    }
}
