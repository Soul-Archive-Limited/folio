import SwiftUI

/// A full-resolution photo for the detail carousel (the calendar's tiles use thumbnails).
/// The thumbnail shows instantly while the full image decodes off the main thread.
struct FullPhotoImage: View {
    let photoID: UUID

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
            guard let data = store.photo(id: photoID)?.imageData else { return }
            image = await ThumbnailCache.decode(data)
        }
        .accessibilityHidden(true)
    }
}
