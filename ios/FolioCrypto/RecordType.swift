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
}
