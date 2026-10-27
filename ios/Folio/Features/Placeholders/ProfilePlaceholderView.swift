import SwiftUI

/// Profile until Phase 7. In DEBUG builds it holds the developer tools.
struct ProfilePlaceholderView: View {
    @Environment(DiaryStore.self) private var store
    @State private var showsCategories = false
    #if DEBUG
    @State private var showsGallery = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    GlassCard {
                        Button { showsCategories = true } label: {
                            Label("Categories", systemImage: "tag")
                                .folioFont(.headline)
                                .foregroundStyle(.ink)
                                .frame(maxWidth: .infinity, minHeight: Spacing.minHitTarget, alignment: .leading)
                        }
                    }
                    #if DEBUG
                    GlassCard {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("Developer").folioFont(.caption).foregroundStyle(.inkTertiary)
                            Button("Design Gallery", systemImage: "swatchpalette") { showsGallery = true }
                            Button("Load sample data", systemImage: "tray.and.arrow.down", action: loadSampleData)
                                .disabled(!store.isEmpty)
                            Button("Erase data on this iPhone", systemImage: "trash", role: .destructive, action: store.eraseAll)
                        }
                        .buttonStyle(.glass)
                    }
                    #endif
                }
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.top, Spacing.xl)
            }
            .background { AuraBackground() }
            .navigationTitle("Profile")
            .navigationDestination(isPresented: $showsCategories) { CategoriesManagerView() }
        }
        #if DEBUG
        .onAppear {
            let open = DebugLaunchOptions.string("FolioOpen")
            if open == "categories" || open == "categoryEdit" { showsCategories = true }
        }
        #endif
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

    #if DEBUG
    private func loadSampleData() {
        PreviewData.loadIfEmpty(into: store)
    }
    #endif
}

#Preview {
    ProfilePlaceholderView()
        .environment(PreviewData.previewStore())
}
