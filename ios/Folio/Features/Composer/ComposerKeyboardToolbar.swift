import PhotosUI
import SwiftUI

/// The glass keyboard toolbar (SPEC §6.4): Aa · Photo · Camera · Category · Mic · ✦.
/// Mic and ✦ are visible but disabled until Phase 8.
struct ComposerKeyboardToolbar: ToolbarContent {
    @Bindable var model: ComposerModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            FormatButton(model: model)
            ComposerPhotoPickerButton(model: model)
            ComposerCameraButton(model: model)
            ComposerCategoryMenu(selection: $model.categoryID)
            Spacer()
            Button("Dictate", systemImage: "mic") {}
                .disabled(true)
                .accessibilityHint("Dictation arrives in a later update")
            Button("Writing tools", systemImage: "sparkles") {}
                .disabled(true)
                .accessibilityHint("Writing tools arrive in a later update")
        }
    }
}

/// The Aa button and its formatting popover.
struct FormatButton: View {
    @Bindable var model: ComposerModel
    @State private var showsPopover = false

    var body: some View {
        Button("Format", systemImage: "textformat") { showsPopover = true }
            .popover(isPresented: $showsPopover) {
                FormatPopover(model: model)
                    .presentationCompactAdaptation(.popover)
            }
    }
}

struct ComposerPhotoPickerButton: View {
    @Bindable var model: ComposerModel
    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        // PhotosPicker runs out of process: no photo-library permission is needed (SPEC §7).
        PhotosPicker(selection: $items, maxSelectionCount: max(model.remainingPhotoSlots, 1), matching: .images) {
            Label("Add photos", systemImage: "photo.on.rectangle")
        }
        .disabled(model.remainingPhotoSlots == 0)
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            Task {
                await model.addPhotos(from: picked)
                items = []
            }
        }
    }
}

struct ComposerCategoryMenu: View {
    @Binding var selection: UUID?
    @Environment(DiaryStore.self) private var store

    var body: some View {
        Menu {
            Picker("Category", selection: $selection) {
                Text("None").tag(UUID?.none)
                ForEach(store.categories()) { category in
                    Label(category.name, systemImage: category.symbol ?? "circle.fill").tag(Optional(category.id))
                }
            }
        } label: {
            Label("Category", systemImage: "tag")
        }
    }
}
