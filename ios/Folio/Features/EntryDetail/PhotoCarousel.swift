import SwiftUI

/// 4:3 paging photo carousel; a tap or pinch opens the photo full screen.
struct PhotoCarousel: View {
    let photoIDs: [UUID]
    let onOpen: (UUID) -> Void

    @State private var current: UUID?

    var body: some View {
        TabView(selection: $current) {
            ForEach(photoIDs, id: \.self) { id in
                FullPhotoImage(photoID: id)
                    .clipShape(.rect(cornerRadius: Radius.photo))
                    .tag(Optional(id))
                    .onTapGesture { onOpen(id) }
                    .gesture(MagnifyGesture().onEnded { value in
                        if value.magnification > 1.1 { onOpen(id) }
                    })
                    .accessibilityLabel("Photo")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens the photo full screen")
                    .accessibilityAction { onOpen(id) }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photoIDs.count > 1 ? .automatic : .never))
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(.rect(cornerRadius: Radius.photo))
        .onAppear { current = photoIDs.first }
    }
}
