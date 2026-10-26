import SwiftUI

/// Decoded photo thumbnails, cached in memory (SPEC §15.1: decoded off the main thread).
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache: NSCache<NSUUID, UIImage> = {
        let cache = NSCache<NSUUID, UIImage>()
        cache.countLimit = 600
        return cache
    }()

    func cachedImage(for id: UUID) -> UIImage? {
        cache.object(forKey: id as NSUUID)
    }

    /// Loads the thumbnail bytes from the store (main actor) and decodes them off-main.
    func image(for id: UUID, store: DiaryStore) async -> UIImage? {
        if let cached = cachedImage(for: id) { return cached }
        guard let data = store.photo(id: id)?.thumbData else { return nil }
        guard let image = await Self.decode(data) else { return nil }
        cache.setObject(image, forKey: id as NSUUID)
        return image
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    @concurrent
    nonisolated static func decode(_ data: Data) async -> UIImage? {
        await UIImage(data: data)?.byPreparingForDisplay()
    }
}
