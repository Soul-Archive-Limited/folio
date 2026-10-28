import Foundation

/// Identifies one image load: the photo, and how many times synced photo bytes have arrived.
struct PhotoLoadKey: Hashable {
    let id: UUID
    let revision: Int
}
