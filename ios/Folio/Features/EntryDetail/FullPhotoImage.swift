import SwiftUI

/// A sharp photo: the detail carousel uses the full image; cards, the Journal grid and the
/// composer strip use the display rendition (day cells keep the 240 px thumbnail). The
/// thumbnail shows instantly while the larger image decodes off the main thread.
struct FullPhotoImage: View {
    let photoID: UUID
    var rendition: DisplayImageCache.Rendition = .full
    /// Longest edge to decode at, in pixels.
    var maxPixel = 1600
    var cornerRadius: Double = 0

    @Environment(DiaryStore.self) private var store
    @State private var shown = ShownPhoto()

    var body: some View {
        // A shape carries the size, so the view is exactly the frame it's given; a ZStack
        // would grow to the scaled-to-fill image and its clip with it, letting the photo draw
        // outside its rounded container (owner's iPhone test, Batch E).
        Rectangle()
            .fill(.clear)
            .overlay { PhotoTile(photoID: photoID, cornerRadius: cornerRadius) }
            .overlay {
                if let image = shown.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(.rect(cornerRadius: cornerRadius))
                        .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .contentShape(.rect(cornerRadius: cornerRadius))
        .animation(.easeOut(duration: 0.2), value: shown.image != nil)
        .task(id: PhotoLoadKey(id: photoID, revision: store.photoBytesRevision)) {
            let id = photoID
            guard shown.begin(id, cached: DisplayImageCache.shared.cached(id, rendition: rendition, maxPixel: maxPixel)) else { return }
            shown.finish(id, image: await DisplayImageCache.shared.image(for: id, rendition: rendition, maxPixel: maxPixel, store: store))
        }
        .accessibilityHidden(true)
    }
}
