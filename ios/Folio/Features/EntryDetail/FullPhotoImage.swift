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
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            PhotoTile(photoID: photoID, cornerRadius: cornerRadius)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .task(id: photoID) {
            image = DisplayImageCache.shared.cached(photoID, rendition: rendition, maxPixel: maxPixel)
            if image == nil {
                image = await DisplayImageCache.shared.image(for: photoID, rendition: rendition, maxPixel: maxPixel, store: store)
            }
        }
        .accessibilityHidden(true)
    }
}
