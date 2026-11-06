import UIKit

/// Identifies one image load: the photo, and how many times synced photo bytes have arrived.
struct PhotoLoadKey: Hashable {
    let id: UUID
    let revision: Int
}

/// The image a photo view shows and which photo it belongs to (Batch K). SwiftUI keeps a view's
/// state when the same card shows a different photo (an entry whose photo was replaced), so the
/// old image must be dropped and the new one loaded; the same photo keeps its image while a sync
/// revision re-checks it.
struct ShownPhoto {
    private(set) var id: UUID?
    private(set) var image: UIImage?

    /// Starts showing `id`; true when its image still has to be loaded.
    mutating func begin(_ id: UUID, cached: UIImage?) -> Bool {
        if let cached {
            self.id = id
            image = cached
            return false
        }
        if self.id != id {
            self.id = id
            image = nil
        }
        return image == nil
    }

    /// A finished load; ignored if the view has moved on to another photo meanwhile.
    mutating func finish(_ id: UUID, image loaded: UIImage?) {
        guard self.id == id, let loaded else { return }
        image = loaded
    }
}
