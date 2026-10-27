import SwiftUI

/// Full-screen photos with pinch to zoom and swipe between them.
struct FullScreenPhotoViewer: View {
    let photoIDs: [UUID]
    let initial: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var current: UUID?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $current) {
                ForEach(photoIDs, id: \.self) { id in
                    ZoomablePhoto(photoID: id).tag(Optional(id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()
            GlassIconButton(title: "Close", systemImage: "xmark") { dismiss() }
                .padding(Spacing.m)
        }
        .onAppear { current = initial }
        .accessibilityAction(.escape) { dismiss() }
    }
}

/// One full-resolution photo that pinches to zoom (1×–4×) and pans while zoomed.
struct ZoomablePhoto: View {
    let photoID: UUID

    @Environment(DiaryStore.self) private var store
    @State private var image: UIImage?
    @State private var scale = 1.0
    @State private var baseScale = 1.0
    @State private var offset = CGSize.zero
    @State private var baseOffset = CGSize.zero

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(MagnifyGesture()
            .onChanged { scale = min(max(baseScale * $0.magnification, 1), 4) }
            .onEnded { _ in
                baseScale = scale
                if scale == 1 { withAnimation(.snappy) { offset = .zero; baseOffset = .zero } }
            })
        .simultaneousGesture(DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: baseOffset.width + value.translation.width, height: baseOffset.height + value.translation.height)
            }
            .onEnded { _ in baseOffset = offset })
        .onTapGesture(count: 2) {
            withAnimation(.snappy) {
                scale = scale > 1 ? 1 : 2.5
                baseScale = scale
                if scale == 1 { offset = .zero; baseOffset = .zero }
            }
        }
        .task(id: photoID) {
            guard let data = store.photo(id: photoID)?.imageData else { return }
            image = await DisplayImageCache.decode(data, maxPixel: 2048)
        }
        .accessibilityLabel("Photo")
    }
}
