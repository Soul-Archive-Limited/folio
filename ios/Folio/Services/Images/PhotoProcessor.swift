import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns picked or captured photos into what Folio stores (SPEC §5):
/// - long edge ≤ 2048 px, HEIC at quality 0.75 (target ≤ 600 KB),
/// - a 1080 px "display" HEIC at quality 0.6 (~150 KB) for cards, grids and the composer,
/// - a 240 px JPEG thumbnail for day cells,
/// - **all** metadata removed, GPS included: images are re-encoded from pixels only, with
///   orientation baked in.
///
/// Runs off the main actor (`@concurrent`): decoding and encoding are the expensive part.
nonisolated struct PhotoProcessor: Sendable {
    var maxPixelSize = 2048
    var displayPixelSize = 1080
    var thumbnailPixelSize = 240
    var imageQuality = 0.75
    var displayQuality = 0.6
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
        let display = try downsample(source, to: displayPixelSize)
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
            imageType: type,
            displayData: try encodeDisplay(display)
        )
    }

    /// The display rendition for a photo stored before renditions had one (backfill).
    @concurrent
    func displayRendition(of imageData: Data) async throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw ProcessingError.unreadableImage }
        return try encodeDisplay(try downsample(source, to: displayPixelSize))
    }

    private func encodeDisplay(_ image: CGImage) throws -> Data {
        if let heic = encode(image, as: .heic, quality: displayQuality) { return heic }
        return try encodeOrThrow(image, as: .jpeg, quality: displayQuality)
    }

    /// The copy that goes to the account (Batch F, DECISIONS 193): browsers other than Safari
    /// can't show HEIC, so a HEIC rendition is re-encoded as JPEG (same pixels, no metadata)
    /// before it's sealed and uploaded. JPEG and anything unreadable pass through unchanged.
    @concurrent
    func syncCopy(of data: Data, quality: Double) async -> Data {
        guard Self.isHEIF(data),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let jpeg = encode(image, as: .jpeg, quality: quality) else { return data }
        return jpeg
    }

    /// An ISO-BMFF `ftyp` box with a HEIF brand.
    static func isHEIF(_ data: Data) -> Bool {
        guard data.count >= 12, data[data.startIndex + 4 ..< data.startIndex + 8] == Data("ftyp".utf8) else { return false }
        let brand = String(decoding: data[data.startIndex + 8 ..< data.startIndex + 12], as: UTF8.self)
        return ["heic", "heix", "hevc", "heim", "heis", "mif1", "msf1"].contains(brand)
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
