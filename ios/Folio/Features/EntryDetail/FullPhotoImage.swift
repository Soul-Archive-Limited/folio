import SwiftUI

/// A full-resolution photo for the detail carousel (the calendar's tiles use thumbnails).
/// The thumbnail shows instantly while the full image decodes off the main thread.
struct FullPhotoImage: View {
    let photoID: UUID
    /// Longest edge to decode at, in pixels.
    var maxPixel = 1600

    @Environment(DiaryStore.self) private var store
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            PhotoTile(photoID: photoID, cornerRadius: 0)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .clipped()
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .task(id: photoID) {
            image = DisplayImageCache.shared.cached(photoID, maxPixel: maxPixel)
            if image == nil { image = await DisplayImageCache.shared.image(for: photoID, maxPixel: maxPixel, store: store) }
        }
        .accessibilityHidden(true)
    }
}
