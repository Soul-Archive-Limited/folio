import PhotosUI
import SwiftUI

/// The composer's glass tool row (SPEC §6.4): Aa · Photo · Camera · Category · Mic · ✦.
/// It sits in the bottom safe-area inset, so it rests at the bottom of the sheet and rides
/// above the keyboard when one is up: the tools are reachable with or without typing.
struct ComposerToolRow: View {
    @Bindable var model: ComposerModel
    /// Nil when dictation isn't available for the chosen language: the mic is hidden, and
    /// Profile points to the keyboard's own mic instead (SPEC §8).
    var onDictate: (() -> Void)?
    /// Nil when Apple's on-device model isn't available: ✦ is hidden (SPEC §9).
    var onWritingTool: ((WritingTool) -> Void)?

    @Environment(TourModel.self) private var tour: TourModel?

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            FormatButton(model: model)
            ComposerPhotoPickerButton(model: model)
            ComposerCameraButton(model: model)
            ComposerCategoryMenu(selection: $model.categoryID)
            Spacer(minLength: 0)
            if let onDictate {
                Button("Dictate", systemImage: "mic", action: onDictate)
                    .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                    .accessibilityInputLabels(["Dictate", "Microphone"])
            }
            if let onWritingTool {
                WritingToolsMenu(onPick: onWritingTool)
            }
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .buttonStyle(.borderless)
        .foregroundStyle(.ink)
        .tint(.ink)
        .padding(.horizontal, Spacing.s)
        .frame(minHeight: 52)
        .folioGlass(in: .capsule)
        .tourTip(ComposerToolsTip.self, tour, arrowEdge: .bottom)
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.bottom, Spacing.xs)
    }
}

/// The Aa button and its formatting popover.
struct FormatButton: View {
    @Bindable var model: ComposerModel
    @State private var showsPopover = false

    var body: some View {
        Button("Format", systemImage: "textformat") { showsPopover = true }
            .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
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
        // The label closure is Sendable, so read the main-actor token here.
        let side = Spacing.minHitTarget
        // PhotosPicker runs out of process: no photo-library permission is needed (SPEC §7).
        PhotosPicker(selection: $items, maxSelectionCount: max(model.remainingPhotoSlots, 1), matching: .images) {
            Label("Add photos", systemImage: "photo.on.rectangle")
                .frame(width: side, height: side)
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
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
        }
    }
}
