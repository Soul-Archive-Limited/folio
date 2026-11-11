import PhotosUI
import SwiftUI

/// Edit profile (Batch N Part 3): the large picture with Choose photo · Folio avatars · Remove
/// photo, and the name under it. Save applies at once and syncs (encrypted settings record);
/// Cancel leaves everything as it was.
struct EditProfileSheet: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var name = ""
    @State private var avatar: String?
    @State private var photo: Data?
    @State private var loaded = false
    @State private var showsPhotoPicker = false
    @State private var showsAvatars = false
    @State private var photoItem: PhotosPickerItem?
    @State private var cropping: CropImage?
    @FocusState private var nameFocused: Bool

    static let maximumNameLength = 40

    struct CropImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    AvatarImage(avatar: avatar, photo: photo, name: name, size: 120)
                        .id("\(avatar ?? "")|\(photo?.count ?? 0)")
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                        .padding(.top, Spacing.m)
                    GlassEffectContainer(spacing: Spacing.xs) {
                        VStack(spacing: Spacing.xs) {
                            // Batch O: side by side split the words into letters at accessibility sizes.
                            (dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(spacing: Spacing.xs))
                                : AnyLayout(HStackLayout(spacing: Spacing.xs))) {
                                Button("Choose photo", image: .folioPhoto) { showsPhotoPicker = true }
                                    .accessibilityIdentifier("editProfile.photo")
                                Button("Folio avatars", systemImage: "face.smiling") { showsAvatars = true }
                                    .accessibilityIdentifier("editProfile.avatars")
                            }
                            if avatar != nil {
                                Button("Remove photo", image: .folioTrash, role: .destructive) {
                                    withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { avatar = nil; photo = nil }
                                }
                                .accessibilityIdentifier("editProfile.remove")
                            }
                        }
                        .buttonStyle(.glass)
                        .folioFont(.callout)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Name").folioFont(.caption).foregroundStyle(.inkSecondary)
                            .accessibilityHidden(true)
                        TextField("Your name", text: $name)
                            .textContentType(.givenName)
                            .submitLabel(.done)
                            .focused($nameFocused)
                            .onSubmit(save)
                            .onChange(of: name) { _, value in
                                if value.count > Self.maximumNameLength { name = String(value.prefix(Self.maximumNameLength)) }
                            }
                            .folioFont(.body)
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: 48)
                            .folioGlass(in: .rect(cornerRadius: 14))
                            .accessibilityLabel("Name")
                            .accessibilityIdentifier("editProfile.name")
                        Text("Used to greet you. It syncs end-to-end encrypted.")
                            .folioFont(.callout).foregroundStyle(.inkSecondary)
                    }
                }
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.bottom, Spacing.xl)
                .animation(FolioMotion.standard(reduceMotion: reduceMotion), value: avatar)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .buttonStyle(.glassProminent).tint(.accentStrong)
                        .accessibilityIdentifier("editProfile.save")
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { SheetSurface() }
        .onAppear(perform: load)
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
            AvatarCropView(image: crop.image) { data in avatar = "photo"; photo = data }
        }
        .sheet(isPresented: $showsAvatars) {
            AvatarPickerSheet { number in avatar = FolioAvatar.key(number); photo = nil }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let settings = store.settings()
        name = settings.displayName
        avatar = settings.avatar
        photo = settings.avatar == "photo" ? settings.avatarPhoto : nil
        #if DEBUG
        switch DebugLaunchOptions.string("FolioOpen") {
        case "avatars": showsAvatars = true
        case "avatarCrop":
            if let data = SampleImageRenderer.jpeg(seed: 3), let image = UIImage(data: data) { cropping = CropImage(image: image) }
        default: break
        }
        #endif
    }

    private func save() {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumNameLength))
        let current = store.settings()
        let newPhoto = avatar == "photo" ? photo : nil
        // Nothing changed: nothing to write or sync.
        guard current.displayName != clean || current.avatar != avatar || (current.avatar == "photo" ? current.avatarPhoto : nil) != newPhoto else {
            dismiss()
            return
        }
        store.updateSettings {
            $0.displayName = clean
            $0.avatar = avatar
            $0.avatarPhoto = avatar == "photo" ? photo : nil
        }
        dismiss()
    }
}
