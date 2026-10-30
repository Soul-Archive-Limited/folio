import CoreTransferable
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Exactly what an entry shares (owner's iPhone test, Batch E): only this entry's own title,
/// date, text and photos — never links into the app or anything from other entries.
struct EntryShareContent {
    let title: String
    let dateLine: String
    let plainText: String
    let photoIDs: [UUID]

    @MainActor
    init(entry: Entry) {
        title = entry.title
        dateLine = entry.day.map { $0.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide).year()) } ?? ""
        plainText = MarkdownCodec.document(from: entry.bodyMarkdown).plainText
        photoIDs = entry.orderedPhotos.map(\.id)
    }

    init(title: String, dateLine: String, plainText: String, photoIDs: [UUID] = []) {
        self.title = title
        self.dateLine = dateLine
        self.plainText = plainText
        self.photoIDs = photoIDs
    }

    /// Title, date, then the text, in plain words.
    var text: String {
        [title, dateLine, plainText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    var previewTitle: String {
        title.isEmpty ? String(localized: "A page from \(dateLine)") : title
    }

    /// Whether the single card leaves some of the text out.
    var isCutOnCard: Bool { plainText.trimmingCharacters(in: .whitespacesAndNewlines).count > 280 }

    /// The first few lines for the image card, cut at a word near 280 characters.
    var openingLines: String {
        let flat = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard flat.count > 280 else { return flat }
        let cut = flat.prefix(280)
        let end = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<end]) + "…"
    }
}

nonisolated enum EntryShareImages {
    /// Re-encodes a stored photo (HEIC) as a JPEG that every app accepts. Stored photos have
    /// no location or camera metadata (SPEC §5), and nothing is added here.
    static func jpeg(from data: Data, quality: Double = 0.85) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func uiImage(_ data: Data, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxPixel]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(UIImage.init(cgImage:))
    }
}
