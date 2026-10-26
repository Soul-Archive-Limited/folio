import Foundation

/// What the composer autosaves every 2 s (SPEC §6.4). Photos aren't part of the draft;
/// they're only kept once the entry is saved.
nonisolated struct ComposerDraft: Codable, Equatable, Sendable {
    /// The entry being edited, or nil for a new entry.
    var entryID: UUID?
    var dayKey: String
    var minutesFromMidnight: Int?
    var title: String
    var bodyMarkdown: String
    var categoryID: UUID?
    var savedAt: Date

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
