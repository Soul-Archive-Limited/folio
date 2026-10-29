/// The record types the server can see (SPEC §10.3). Raw values are part of the
/// encryption's associated data and the sync API, so they must never change.
public enum RecordType: String, CaseIterable, Codable, Sendable {
    case entry
    case entryPhoto
    case task
    case category
    case settings
    /// Encrypted full-size photo blob in R2.
    case photoBlob = "photo"
    /// Encrypted thumbnail blob in R2.
    case thumbnailBlob = "thumb"
    /// Encrypted 1080 px display rendition in R2 (Phase 10).
    case displayBlob = "display"
    /// A name the person gave one of their devices, stored on its session (Batch F).
    case deviceLabel
}
