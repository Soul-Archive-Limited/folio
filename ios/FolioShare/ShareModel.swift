import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Loads what was shared and saves it to Folio's encrypted inbox (Batch J).
@MainActor
@Observable
final class ShareModel {
    private let items: [NSExtensionItem]
    private(set) var isLoading = true
    private(set) var photos: [Data] = []
    private(set) var previews: [UIImage] = []
    private(set) var link: URL?
    var text = ""
    var note = ""
    var title = ""
    var day = Date()
    var categoryID: UUID?
    var appendsToDay = false
    private(set) var problem: String?
    let context: ShareInbox.Context?

    static let maximumPhotos = 10

    init(items: [NSExtensionItem]) {
        self.items = items
        context = ShareInbox.readContext()
        categoryID = context?.defaultCategoryID
    }

    var dayKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    var dayHasPage: Bool { context?.daysWithPages.contains(dayKey) == true }
    var hasContent: Bool { !photos.isEmpty || link != nil || !text.isEmpty || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func load() async {
        defer { isLoading = false }
        for item in items {
            if title.isEmpty, let content = item.attributedContentText?.string, !content.isEmpty { text = content }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier), photos.count < Self.maximumPhotos {
                    if let data = await loadImage(provider) {
                        photos.append(data)
                        if let image = UIImage(data: data) { previews.append(image) }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier), link == nil {
                    link = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
                    if let link, link.scheme != "https", link.scheme != "http" { self.link = nil }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier), text.isEmpty {
                    text = (try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String) ?? ""
                }
            }
        }
        text = String(text.prefix(20_000))
        if photos.count >= Self.maximumPhotos { problem = String(localized: "A page holds 10 photos; the first 10 are kept.") }
    }

    /// The image from a file, resized on the way in (≤ 2048 px) so ten photos fit in the
    /// extension's small memory budget.
    private func loadImage(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(for: .image) { url, _, _ in
                guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                          kCGImageSourceCreateThumbnailFromImageAlways: true,
                          kCGImageSourceCreateThumbnailWithTransform: true,
                          kCGImageSourceThumbnailMaxPixelSize: 2048,
                      ] as CFDictionary) else { continuation.resume(returning: nil); return }
                continuation.resume(returning: UIImage(cgImage: image).jpegData(compressionQuality: 0.85))
            }
        }
    }

    func save() -> Bool {
        let words = [note.trimmingCharacters(in: .whitespacesAndNewlines), text.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
        let item = ShareInbox.Item(dayKey: dayKey, categoryID: categoryID, appendsToDay: appendsToDay && dayHasPage,
                                   title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : String(title.prefix(120)),
                                   text: words.isEmpty ? nil : words, link: link?.absoluteString, photos: photos)
        do {
            try ShareInbox.add(item)
            return true
        } catch {
            problem = String(localized: "Couldn't save to Folio. Open Folio once, then try again.")
            return false
        }
    }
}
