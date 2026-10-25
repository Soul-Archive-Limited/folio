#if DEBUG
import SwiftUI

/// DEBUG-only catalogue of every design-system component (Phase 1).
/// Open it with the launch argument `-FolioScreen gallery`, or from the DEBUG menu.
struct DesignGalleryView: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    GalleryComponentsSection()
                    GalleryFeedbackSection(toasts: toasts)
                    GalleryMotionSection()
                    GalleryTypeSection()
                    GalleryCategorySection()
                    GalleryColorsSection()
                }
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.bottom, 96)
            }
            .background { AuraBackground() }
            .navigationTitle("Design Gallery")
        }
        .toastHost(toasts)
    }
}

#Preview("Light") {
    DesignGalleryView()
}

#Preview("Dark") {
    DesignGalleryView().preferredColorScheme(.dark)
}
#endif
