import LinkPresentation
import SwiftUI
import UIKit

/// The entry's text as a plain `String` item — what every text receiver accepts (WhatsApp's
/// Next stayed disabled when `ShareLink` sent the text with an image preview, Batch I) — plus a
/// subject for Mail and link metadata so the share sheet's header shows the title and photo.
/// Photos, when shared, are separate items: one item can't mix text and images.
final class PreviewTextItem: NSObject, UIActivityItemSource {
    let text: String
    let title: String
    let thumbnail: UIImage?

    init(text: String, title: String, thumbnail: UIImage?) {
        self.text = text
        self.title = title
        self.thumbnail = thumbnail
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { text }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? { text }

    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType type: UIActivity.ActivityType?) -> String { title }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        if let thumbnail { metadata.iconProvider = NSItemProvider(object: thumbnail) }
        return metadata
    }
}

extension View {
    /// Presents the share sheet for one way of sharing an entry (`EntryShareMenu`).
    func entryShare(_ kind: Binding<EntryShareKind?>, entry: Entry?) -> some View {
        modifier(EntryShareModifier(kind: kind, entry: entry))
    }
}

private struct EntryShareModifier: ViewModifier {
    @Binding var kind: EntryShareKind?
    let entry: Entry?

    @Environment(DiaryStore.self) private var store

    func body(content: Content) -> some View {
        content.sheet(item: $kind) { kind in
            if let entry {
                ActivityShareSheet(items: items(kind, entry: entry))
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
        }
    }

    private func items(_ kind: EntryShareKind, entry: Entry) -> [Any] {
        let share = EntryShareContent(entry: entry)
        let photos = entry.orderedPhotos
        let thumbnail = photos.first.flatMap { UIImage(data: $0.thumbData) }
        let textItem = PreviewTextItem(text: share.text, title: share.previewTitle, thumbnail: thumbnail)
        let writingFont = WritingFont(rawValue: store.settings().writingFont) ?? .newYork
        let cardPhoto = photos.first.flatMap { EntryShareImages.uiImage($0.displayOrFullData, maxPixel: 1200) }
        switch kind {
        case .text:
            return [textItem]
        case .textAndPhotos:
            return [textItem] + photos.compactMap { EntryShareImages.uiImage($0.imageData, maxPixel: 2048) }
        case .singleCard:
            return [EntryShareCard.png(content: share, photo: cardPhoto, writingFont: writingFont).flatMap(UIImage.init(data:))]
                .compactMap { $0 }
        case .allPages:
            return EntryStoryPages.images(content: share, photo: cardPhoto, writingFont: writingFont)
        }
    }
}

/// The system share sheet with any items.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
