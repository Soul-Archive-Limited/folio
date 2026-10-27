import SwiftUI

/// The three ways to share an entry, as menu items (entry detail's Share menu and the cards'
/// long-press menu): text only, text and photos, or one image card. Every option shows a
/// proper preview (title + thumbnail) in the share sheet.
struct EntryShareMenu: View {
    let entry: Entry
    /// Opens the text-and-photos share sheet (`textAndPhotosShare`), owned by the caller.
    let onShareTextAndPhotos: () -> Void

    @Environment(DiaryStore.self) private var store

    var body: some View {
        let content = EntryShareContent(entry: entry)
        let preview = sharePreview(content)
        ShareLink(item: content.text, subject: Text(content.previewTitle), preview: preview) {
            Label("Share as text", systemImage: "text.alignleft")
        }
        if !content.photoIDs.isEmpty {
            Button("Share text and photos", systemImage: "photo.on.rectangle", action: onShareTextAndPhotos)
        }
        ShareLink(item: cardImage(content), preview: preview) {
            Label("Share as image", systemImage: "rectangle.portrait.on.rectangle.portrait")
        }
    }

    private func sharePreview(_ content: EntryShareContent) -> SharePreview<Image, Never> {
        SharePreview(content.previewTitle, image: thumbnail(content).map(Image.init(uiImage:)) ?? Image(.appMark))
    }

    private func thumbnail(_ content: EntryShareContent) -> UIImage? {
        content.photoIDs.first.flatMap(store.photo(id:)).flatMap { UIImage(data: $0.thumbData) }
    }

    private func cardImage(_ content: EntryShareContent) -> EntryShareCardImage {
        let photoData = content.photoIDs.first.flatMap(store.photo(id:))?.displayOrFullData
        let writingFont = WritingFont(rawValue: store.settings().writingFont) ?? .newYork
        return EntryShareCardImage {
            EntryShareCard.png(content: content, photo: photoData.flatMap { EntryShareImages.uiImage($0, maxPixel: 1200) },
                               writingFont: writingFont)
        }
    }
}
