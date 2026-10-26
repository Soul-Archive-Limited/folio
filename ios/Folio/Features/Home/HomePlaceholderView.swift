import SwiftUI

/// Stand-in for the tab shell until Phase 3.
struct HomePlaceholderView: View {
    @Environment(DiaryStore.self) private var store
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
                Button("Load sample data", systemImage: "tray.and.arrow.down", action: loadSampleData)
                    .buttonStyle(.glass)
                    .disabled(!store.isEmpty)
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

#if DEBUG
extension HomePlaceholderView {
    private func loadSampleData() {
        PreviewData.loadIfEmpty(into: store)
    }
}
#endif

#Preview {
    HomePlaceholderView()
        .environment(PreviewData.previewStore())
}
