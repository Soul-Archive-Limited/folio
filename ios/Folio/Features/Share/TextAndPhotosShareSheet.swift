import LinkPresentation
import SwiftUI
import UIKit

/// "Share text and photos": the system share sheet with the entry's text and each photo as
/// separate items (a single `Transferable` type can't mix text and images — the share sheet
/// then treats the text as an image too). The text item supplies the preview (title +
/// thumbnail).
struct TextAndPhotosShareSheet: UIViewControllerRepresentable {
    let text: String
    let title: String
    let photos: [UIImage]
    let thumbnail: UIImage?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let textItem = PreviewTextItem(text: text, title: title, thumbnail: thumbnail)
        return UIActivityViewController(activityItems: [textItem] + photos, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// The entry's text, with link metadata so the share sheet header shows its title and photo.
private final class PreviewTextItem: NSObject, UIActivityItemSource {
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
    /// Presents "Share text and photos" for an entry.
    func textAndPhotosShare(isPresented: Binding<Bool>, entry: Entry?) -> some View {
        modifier(TextAndPhotosShareModifier(isPresented: isPresented, entry: entry))
    }
}

private struct TextAndPhotosShareModifier: ViewModifier {
    @Binding var isPresented: Bool
    let entry: Entry?

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            if let entry {
                let share = EntryShareContent(entry: entry)
                let photos = entry.orderedPhotos
                TextAndPhotosShareSheet(text: share.text, title: share.previewTitle,
                                        photos: photos.compactMap { EntryShareImages.uiImage($0.imageData, maxPixel: 2048) },
                                        thumbnail: photos.first.flatMap { UIImage(data: $0.thumbData) })
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
        }
    }
}
