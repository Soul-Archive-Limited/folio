import ImageIO
import SwiftUI

/// Photos decoded at the size they're shown, cached by photo, rendition and size. Cards,
/// grids and the composer read the 1080 px display rendition; the detail carousel reads the
/// full image. Decoding a 2048 px HEIC for a 120 pt tile would waste memory.
final class DisplayImageCache {
    enum Rendition: String { case display, full }

    static let shared = DisplayImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 120 * 1024 * 1024
        return cache
    }()

    func cached(_ id: UUID, rendition: Rendition, maxPixel: Int) -> UIImage? {
        cache.object(forKey: key(id, rendition, maxPixel))
    }

    func image(for id: UUID, rendition: Rendition, maxPixel: Int, store: DiaryStore) async -> UIImage? {
        if let cached = cached(id, rendition: rendition, maxPixel: maxPixel) { return cached }
        guard let photo = store.photo(id: id) else { return nil }
        let data = rendition == .display ? photo.displayOrFullData : photo.imageData
        guard let image = await Self.decode(data, maxPixel: maxPixel) else { return nil }
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key(id, rendition, maxPixel), cost: cost)
        return image
    }

    func removeAll() { cache.removeAllObjects() }

    private func key(_ id: UUID, _ rendition: Rendition, _ maxPixel: Int) -> NSString {
        "\(id.uuidString)-\(rendition.rawValue)-\(maxPixel)" as NSString
    }

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
