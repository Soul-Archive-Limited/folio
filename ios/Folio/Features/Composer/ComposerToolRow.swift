import PhotosUI
import SwiftUI

/// The composer's glass tool row (SPEC §6.4): Aa · Photo · Camera · Category · Mood · Place · Mic · ✦.
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
        // Eight 44 pt tools (Batch N added Place) are wider than an iPhone with the usual
        // spacing and margins: tighten first, and on the narrowest screens let the row scroll,
        // so the tools never widen the sheet (which clipped the title before).
        ViewThatFits(in: .horizontal) {
            bar(spacing: Spacing.xxs, inset: Spacing.s, margin: Spacing.sideMargin)
            bar(spacing: 0, inset: Spacing.xs, margin: Spacing.s)
            ScrollView(.horizontal) { tools(spacing: 0, flexible: false) }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, Spacing.xs, for: .scrollContent)
                .modifier(ToolRowChrome(inset: 0, margin: Spacing.s))
        }
        .tourAnchor(.composerTools, tour)
        .padding(.bottom, Spacing.xs)
    }

    private func bar(spacing: Double, inset: Double, margin: Double) -> some View {
        tools(spacing: spacing, flexible: true).modifier(ToolRowChrome(inset: inset, margin: margin))
    }

    private func tools(spacing: Double, flexible: Bool) -> some View {
        HStack(spacing: spacing) {
            FormatButton(model: model)
            ComposerPhotoPickerButton(model: model)
            ComposerCameraButton(model: model)
            ComposerCategoryMenu(selection: $model.categoryID)
            ComposerMoodButton(mood: $model.mood)
            ComposerPlaceButton(model: model)
            if flexible { Spacer(minLength: 0) }
            if let onDictate {
                // The 44 pt frame sits inside the label so the whole square is the hit area.
                Button(action: onDictate) {
                    Label("Dictate", image: "folio.dictate")
                        .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                        .contentShape(.rect)
                }
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
    }
}

/// The glass capsule around the tool row.
private struct ToolRowChrome: ViewModifier {
    let inset: Double
    let margin: Double

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, inset)
            .frame(minHeight: 52)
            .folioGlass(in: .capsule)
            .padding(.horizontal, margin)
    }
}

/// The Aa button and its formatting popover.
struct FormatButton: View {
    @Bindable var model: ComposerModel
    @State private var showsPopover = false

    var body: some View {
        Button { showsPopover = true } label: {
            Label("Format", systemImage: "textformat")
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                .contentShape(.rect)
        }
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
            Label("Add photos", image: "folio.photo")
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
            Label("Category", image: "folio.category")
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
        }
    }
}
