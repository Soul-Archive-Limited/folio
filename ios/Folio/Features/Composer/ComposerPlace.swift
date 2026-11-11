import SwiftUI

/// The Place button in the composer's tool row (Batch N). Filled when the entry has a place.
struct ComposerPlaceButton: View {
    @Bindable var model: ComposerModel
    @State private var showsSheet = false

    var body: some View {
        Button { showsSheet = true } label: {
            Label(model.place == nil ? "Add place" : "Place, \(model.place?.name ?? "")", image: .folioPlace)
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
                .contentShape(.rect)
                .foregroundStyle(model.place == nil ? Color.ink : Color.accent)
        }
        .accessibilityIdentifier("composer.place")
        .sheet(isPresented: $showsSheet) { PlaceSheet(place: $model.place) }
        #if DEBUG
        .task {
            guard model.debugOpensPlaceSheet else { return }
            try? await Task.sleep(for: .milliseconds(600))
            showsSheet = true
        }
        #endif
    }
}

/// Under the title: the chosen place as a small chip (tap to change, × to remove), or the
/// offer made from a photo's location — "Add Tate Modern?" — which stores nothing until accepted.
struct ComposerPlaceRow: View {
    @Bindable var model: ComposerModel
    @State private var showsSheet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let place = model.place {
                HStack(spacing: Spacing.xxs) {
                    Button { showsSheet = true } label: {
                        Label(place.name, image: .folioPlace)
                            .folioFont(.callout)
                            .lineLimit(1)
                    }
                    .accessibilityHint("Changes the place")
                    Button { model.place = nil } label: {
                        Image(systemName: "xmark").font(.caption2.weight(.semibold))
                            .frame(width: 28, height: 28).contentShape(.rect)
                    }
                    .accessibilityLabel("Remove place")
                }
                .padding(.leading, Spacing.s)
                .padding(.trailing, Spacing.xxs)
                .frame(minHeight: 34)
                .foregroundStyle(.inkSecondary)
                .folioGlass(in: .capsule)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let offer = model.placeOffer {
                HStack(spacing: Spacing.xs) {
                    Image(.folioPlace).foregroundStyle(.accent).accessibilityHidden(true)
                    Text("Add \(offer.name)?")
                        .folioFont(.callout).foregroundStyle(.ink).lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    Button("Not now") { model.declinePlaceOffer() }
                        .folioFont(.callout).foregroundStyle(.inkSecondary)
                    Button("Add") { model.acceptPlaceOffer() }
                        .folioFont(.callout).fontWeight(.semibold)
                        .buttonStyle(.glassProminent).tint(.accentStrong)
                        .accessibilityHint("Adds the place this photo was taken")
                }
                .padding(.leading, Spacing.s)
                .padding(.trailing, Spacing.xxs)
                .frame(minHeight: 40)
                .folioGlass(in: .capsule)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("composer.placeOffer")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? FolioMotion.reduced : .spring(duration: 0.35, bounce: 0.15), value: model.place)
        .animation(reduceMotion ? FolioMotion.reduced : .spring(duration: 0.35, bounce: 0.15), value: model.placeOffer)
        .sheet(isPresented: $showsSheet) { PlaceSheet(place: $model.place) }
    }
}
