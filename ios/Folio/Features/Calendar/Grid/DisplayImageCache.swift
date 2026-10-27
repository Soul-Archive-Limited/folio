import ImageIO
import SwiftUI

/// Full photos decoded at the size they're shown (journal covers, the detail carousel),
/// cached by photo and size. Decoding a 2048 px HEIC for a 360 pt card would waste memory.
final class DisplayImageCache {
    static let shared = DisplayImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 120 * 1024 * 1024
        return cache
    }()

    func cached(_ id: UUID, maxPixel: Int) -> UIImage? {
        cache.object(forKey: key(id, maxPixel))
    }

    func image(for id: UUID, maxPixel: Int, store: DiaryStore) async -> UIImage? {
        if let cached = cached(id, maxPixel: maxPixel) { return cached }
        guard let data = store.photo(id: id)?.imageData, let image = await Self.decode(data, maxPixel: maxPixel) else { return nil }
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key(id, maxPixel), cost: cost)
        return image
    }

    func removeAll() { cache.removeAllObjects() }

    private func key(_ id: UUID, _ maxPixel: Int) -> NSString { "\(id.uuidString)-\(maxPixel)" as NSString }

    @concurrent
    nonisolated static func decode(_ data: Data, maxPixel: Int) async -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
