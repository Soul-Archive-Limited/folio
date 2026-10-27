import Foundation

/// What the composer autosaves every 2 s (SPEC §6.4), photos included: new photos are kept
/// as files next to the draft (`DraftStore`), photos already on the entry by their ID.
nonisolated struct ComposerDraft: Codable, Equatable, Sendable {
    /// The entry being edited, or nil for a new entry.
    var entryID: UUID?
    var dayKey: String
    var minutesFromMidnight: Int?
    var title: String
    var bodyMarkdown: String
    var categoryID: UUID?
    var photos: [DraftPhoto] = []
    var savedAt: Date

    /// Same writing, ignoring when it was saved and whitespace at the ends of the text, so a
    /// draft that only repeats the saved entry never counts as unsaved work.
    func hasSameContent(as other: ComposerDraft) -> Bool {
        func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
        return entryID == other.entryID && dayKey == other.dayKey && minutesFromMidnight == other.minutesFromMidnight
            && trimmed(title) == trimmed(other.title) && trimmed(bodyMarkdown) == trimmed(other.bodyMarkdown)
            && categoryID == other.categoryID
            && photos.map { $0.storedPhotoID ?? $0.id } == other.photos.map { $0.storedPhotoID ?? $0.id }
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && photos.isEmpty
    }

    init(entryID: UUID?, dayKey: String, minutesFromMidnight: Int?, title: String, bodyMarkdown: String,
         categoryID: UUID?, photos: [DraftPhoto] = [], savedAt: Date) {
        self.entryID = entryID
        self.dayKey = dayKey
        self.minutesFromMidnight = minutesFromMidnight
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.categoryID = categoryID
        self.photos = photos
        self.savedAt = savedAt
    }

    /// Drafts written before photos were kept have no `photos` key.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entryID = try container.decodeIfPresent(UUID.self, forKey: .entryID)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        minutesFromMidnight = try container.decodeIfPresent(Int.self, forKey: .minutesFromMidnight)
        title = try container.decode(String.self, forKey: .title)
        bodyMarkdown = try container.decode(String.self, forKey: .bodyMarkdown)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        photos = try container.decodeIfPresent([DraftPhoto].self, forKey: .photos) ?? []
        savedAt = try container.decode(Date.self, forKey: .savedAt)
    }
}

/// One photo in a draft, in order: either already stored on the entry, or a new photo whose
/// renditions are files in the draft's photo folder.
nonisolated struct DraftPhoto: Codable, Equatable, Sendable {
    var id: UUID
    var storedPhotoID: UUID?
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0
    var imageType: String = "public.heic"
}
