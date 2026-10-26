import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns picked or captured photos into what Folio stores (SPEC §5):
/// - long edge ≤ 2048 px, HEIC at quality 0.75 (target ≤ 600 KB),
/// - a 240 px JPEG thumbnail,
/// - **all** metadata removed, GPS included: images are re-encoded from pixels only, with
///   orientation baked in.
///
/// Runs off the main actor (`@concurrent`): decoding and encoding are the expensive part.
nonisolated struct PhotoProcessor: Sendable {
    var maxPixelSize = 2048
    var thumbnailPixelSize = 240
    var imageQuality = 0.75
    var thumbnailQuality = 0.7

    enum ProcessingError: Error, Equatable {
        case unreadableImage
        case encodingFailed
    }

    @concurrent
    func process(_ data: Data) async throws -> ProcessedPhoto {
        try processSynchronously(data)
    }

    func processSynchronously(_ data: Data) throws -> ProcessedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw ProcessingError.unreadableImage }
        let full = try downsample(source, to: maxPixelSize)
        let thumbnail = try downsample(source, to: thumbnailPixelSize)

        let heic = encode(full, as: .heic, quality: imageQuality)
        let (imageData, type) = if let heic { (heic, UTType.heic.identifier) } else {
            (try encodeOrThrow(full, as: .jpeg, quality: imageQuality), UTType.jpeg.identifier)
        }
        return ProcessedPhoto(
            imageData: imageData,
            thumbnailData: try encodeOrThrow(thumbnail, as: .jpeg, quality: thumbnailQuality),
            pixelWidth: full.width,
            pixelHeight: full.height,
            imageType: type
        )
    }

    /// Decodes straight to the target size (never the full-resolution bitmap) and applies
    /// the EXIF orientation so the stored pixels are upright.
    private func downsample(_ source: CGImageSource, to maxPixel: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ProcessingError.unreadableImage
        }
        return image
    }

    /// Writes pixels only: no properties dictionary is copied, so no EXIF, GPS, TIFF or
    /// maker notes survive.
    private func encode(_ image: CGImage, as type: UTType, quality: Double) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private func encodeOrThrow(_ image: CGImage, as type: UTType, quality: Double) throws -> Data {
        guard let data = encode(image, as: type, quality: quality) else { throw ProcessingError.encodingFailed }
        return data
    }
}
