import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Folio

@Suite("Photo pipeline (SPEC §5)")
struct PhotoProcessorTests {
    /// A 4000×3000 JPEG carrying GPS coordinates and an EXIF "rotate 90°" orientation.
    static func photoWithGPS(orientation: Int = 6) throws -> Data {
        let context = try #require(CGContext(data: nil, width: 4000, height: 3000, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 51.5007, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 0.1246, kCGImagePropertyGPSLongitudeRef: "W",
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private"],
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    static func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
    }

    @Test("Source fixture really contains GPS")
    func fixtureHasGPS() throws {
        #expect(try Self.properties(of: Self.photoWithGPS())[kCGImagePropertyGPSDictionary] != nil)
    }

    @Test("GPS and EXIF are stripped; size is capped at 2048 with orientation applied")
    func process() async throws {
        let processed = try await PhotoProcessor().process(try Self.photoWithGPS())
        // Orientation 6 means the stored pixels are portrait once rotated upright.
        #expect(processed.pixelWidth == 1536)
        #expect(processed.pixelHeight == 2048)

        for data in [processed.imageData, processed.displayData, processed.thumbnailData] {
            let properties = try Self.properties(of: data)
            #expect(properties[kCGImagePropertyGPSDictionary] == nil)
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
            #expect(exif?[kCGImagePropertyExifUserComment] == nil)
            #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        }

        let thumb = try Self.properties(of: processed.thumbnailData)
        let thumbSize = max(thumb[kCGImagePropertyPixelWidth] as? Int ?? 0, thumb[kCGImagePropertyPixelHeight] as? Int ?? 0)
        #expect(thumbSize == 240)
        #expect(processed.thumbnailData.count < 25_000)
        #expect(processed.imageData.count < 600_000)
    }

    @Test("The display rendition is a 1080 px HEIC of about 150 KB")
    func displayRendition() throws {
        let jpeg = try #require(SampleImageRenderer.jpeg(seed: 5, width: 4000, height: 3000))
        let processed = try PhotoProcessor().processSynchronously(jpeg)
        let display = try Self.properties(of: processed.displayData)
        let longEdge = max(display[kCGImagePropertyPixelWidth] as? Int ?? 0, display[kCGImagePropertyPixelHeight] as? Int ?? 0)
        #expect(longEdge == 1080)
        #expect(processed.displayData.count < 250_000)
        #expect(processed.displayData.count < processed.imageData.count)
    }

    @Test("Small photos are not upscaled")
    func noUpscale() throws {
        let jpeg = try #require(SampleImageRenderer.jpeg(seed: 2, width: 800, height: 600))
        let processed = try PhotoProcessor().processSynchronously(jpeg)
        #expect(processed.pixelWidth == 800 && processed.pixelHeight == 600)
    }

    @Test("Garbage data is rejected")
    func garbage() {
        #expect(throws: PhotoProcessor.ProcessingError.unreadableImage) {
            try PhotoProcessor().processSynchronously(Data("not an image".utf8))
        }
    }
}
