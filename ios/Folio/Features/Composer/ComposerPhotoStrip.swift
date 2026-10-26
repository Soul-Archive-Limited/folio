import SwiftUI

/// Photos in the composer (SPEC §6.4): long-press and drag to reorder, × to remove.
struct ComposerPhotoStrip: View {
    @Bindable var model: ComposerModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(model.photos) { photo in
                    ComposerPhotoThumb(photo: photo) { model.removePhoto(photo) }
                        .draggable(photo.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                            model.movePhoto(id, before: photo.id)
                            return true
                        }
                }
                if model.isProcessingPhotos {
                    ProgressView()
                        .frame(width: 72, height: 72)
                        .folioGlass(in: .rect(cornerRadius: 14))
                }
            }
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .animation(FolioMotion.standard(), value: model.photos)
    }
}

/// One thumbnail with its remove button.
struct ComposerPhotoThumb: View {
    let photo: ComposerPhoto
    let onRemove: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let stored = photo.storedPhotoID {
                PhotoTile(photoID: stored, cornerRadius: 14)
            } else {
                Rectangle().fill(.hairline)
                    .overlay {
                        if let image { Image(uiImage: image).resizable().scaledToFill() }
                    }
                    .clipShape(.rect(cornerRadius: 14))
                    .task {
                        if let data = photo.processed?.thumbnailData { image = await ThumbnailCache.decode(data) }
                    }
            }
        }
        .frame(width: 72, height: 72)
        .overlay(alignment: .topTrailing) {
            Button("Remove photo", systemImage: "xmark", action: onRemove)
                .labelStyle(.iconOnly)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.black.opacity(0.55), in: .circle)
                .padding(4)
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget, alignment: .topTrailing)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo")
    }
}
