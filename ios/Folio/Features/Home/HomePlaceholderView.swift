import SwiftUI

/// Stand-in for the tab shell until Phase 3.
struct HomePlaceholderView: View {
    #if DEBUG
    @State private var showsGallery = false
    #endif

    var body: some View {
        ZStack {
            AuraBackground()
            VStack(spacing: Spacing.l) {
                Text("Folio").folioFont(.title1)
                #if DEBUG
                Button("Design Gallery", systemImage: "swatchpalette") { showsGallery = true }
                    .buttonStyle(.glass)
                #endif
            }
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showsGallery) {
            DesignGalleryView()
                .overlay(alignment: .topTrailing) {
                    GlassIconButton(title: "Close", systemImage: "xmark") { showsGallery = false }
                        .padding(Spacing.m)
                }
                .privacyCovered()
        }
        #endif
    }
}

#Preview {
    HomePlaceholderView()
}
