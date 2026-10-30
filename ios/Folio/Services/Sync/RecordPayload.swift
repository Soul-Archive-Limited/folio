import Foundation

/// The JSON inside each record's ciphertext (SPEC §10.3). Everything the server mustn't see —
/// titles, text, days, categories, Recently Deleted state — lives here. Times are
/// milliseconds since 1970; ids are UUID strings, compared case-insensitively (the web app
/// reads the same JSON).
nonisolated enum RecordPayload {
    struct Entry: Codable, Equatable, Sendable {
        var title: String
        var bodyMarkdown: String
        var dayKey: String
        var minutesFromMidnight: Int?
        var categoryID: UUID?
        var createdAt: Date
        var trashedAt: Date?
    }

    /// Photo metadata; the image bytes are three encrypted blobs in R2.
    struct EntryPhoto: Codable, Equatable, Sendable {
        var entryID: UUID
        var sortIndex: Int
        var pixelWidth: Int
        var pixelHeight: Int
        var createdAt: Date
    }

    struct Task: Codable, Equatable, Sendable {
        var title: String
        var notes: String?
        var dayKey: String?
        var minutesFromMidnight: Int?
        var categoryID: UUID?
        var isCompleted: Bool
        var completedAt: Date?
        var sortIndex: Int
        var createdAt: Date
        var trashedAt: Date?
        /// Batch I (schema v4); older apps leave them out.
        var remindAt: String?
        var repeatRule: String?
        var parentID: UUID?
    }

    struct Category: Codable, Equatable, Sendable {
        var name: String
        var colorKey: String
        var symbol: String?
        var sortIndex: Int
        var createdAt: Date
        var trashedAt: Date?
        var unassignedIDs: [UUID]?
    }

    struct Settings: Codable, Equatable, Sendable {
        var displayName: String
        var appearance: String
        var writingFont: String
        var firstWeekday: Int?
        var defaultCategoryID: UUID?
        var createdAt: Date
        /// Batch I (schema v4): "folio:07", "photo" or absent; the photo is a small JPEG.
        var avatar: String?
        var avatarPhoto: Data?
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
