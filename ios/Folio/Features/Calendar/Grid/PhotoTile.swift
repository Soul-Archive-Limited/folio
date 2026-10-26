import SwiftUI

/// A photo thumbnail in a fixed frame; it fades in when decoded, so nothing shifts
/// (SPEC §3.6 "no layout jumps"). Shows a soft shimmer while loading (§6.14).
struct PhotoTile: View {
    let photoID: UUID
    var cornerRadius: Double = Radius.dayCell

    @Environment(DiaryStore.self) private var store
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(.hairline)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.hairline, lineWidth: 1)
            }
            .animation(.easeOut(duration: 0.2), value: image != nil)
            .task(id: photoID) {
                image = ThumbnailCache.shared.cachedImage(for: photoID)
                if image == nil { image = await ThumbnailCache.shared.image(for: photoID, store: store) }
            }
            .accessibilityHidden(true)
    }
}
