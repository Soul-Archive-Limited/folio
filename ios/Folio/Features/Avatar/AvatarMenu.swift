import PhotosUI
import SwiftUI

/// Tap the avatar: "Choose photo" (PhotosPicker, then the circular crop) or "Folio avatars";
/// "Remove picture" when one is set (Batch I). The choice is a synced setting.
struct AvatarMenu<Label: View>: View {
    @ViewBuilder let label: () -> Label

    @Environment(DiaryStore.self) private var store
    @State private var showsPhotoPicker = false
    @State private var showsAvatars = false
    @State private var photoItem: PhotosPickerItem?
    @State private var cropping: CropImage?

    struct CropImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        Menu {
            Button("Choose photo", systemImage: "photo") { showsPhotoPicker = true }
            Button("Folio avatars", systemImage: "face.smiling") { showsAvatars = true }
            if store.settings().avatar != nil {
                Button("Remove picture", systemImage: "trash", role: .destructive) {
                    store.updateSettings { $0.avatar = nil; $0.avatarPhoto = nil }
                }
            }
        } label: {
            label()
        }
        .accessibilityLabel("Profile picture")
        .accessibilityHint("Choose a photo or a Folio avatar")
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = EntryShareImages.uiImage(data, maxPixel: 1600) {
                    cropping = CropImage(image: image)
                }
                photoItem = nil
            }
        }
        .sheet(item: $cropping) { crop in
            AvatarCropView(image: crop.image) { data in
                store.updateSettings { $0.avatar = "photo"; $0.avatarPhoto = data }
            }
        }
        #if DEBUG
        .onAppear {
            switch DebugLaunchOptions.string("FolioOpen") {
            case "avatars": showsAvatars = true
            case "avatarCrop":
                if let data = SampleImageRenderer.jpeg(seed: 3), let image = UIImage(data: data) { cropping = CropImage(image: image) }
            default: break
            }
        }
        #endif
        .sheet(isPresented: $showsAvatars) {
            AvatarPickerSheet { number in
                store.updateSettings { $0.avatar = FolioAvatar.key(number); $0.avatarPhoto = nil }
            }
        }
    }
}
