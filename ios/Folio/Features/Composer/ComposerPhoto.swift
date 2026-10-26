import SwiftUI

/// A photo in the composer: either already saved on the entry, or newly picked and
/// processed but not saved yet.
struct ComposerPhoto: Identifiable, Equatable {
    let id: UUID
    /// Set for photos already stored on the entry.
    let storedPhotoID: UUID?
    /// Set for new photos until the entry is saved.
    let processed: ProcessedPhoto?

    static func stored(_ id: UUID) -> ComposerPhoto {
        ComposerPhoto(id: id, storedPhotoID: id, processed: nil)
    }

    static func new(_ processed: ProcessedPhoto) -> ComposerPhoto {
        ComposerPhoto(id: UUID(), storedPhotoID: nil, processed: processed)
    }
}
