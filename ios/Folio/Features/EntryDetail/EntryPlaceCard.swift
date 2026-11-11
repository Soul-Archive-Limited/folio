import SwiftUI

/// The place at the end of an entry (Batch N): a compact map with the name and address; tap
/// opens the full map with "Open in Maps". A place added by name only (on the web) shows the
/// line and opens Maps' search.
struct EntryPlaceCard: View {
    let place: Place

    @State private var showsMap = false

    var body: some View {
        Button {
            if place.hasCoordinate { showsMap = true } else { PlaceResolver.openInMaps(place) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let coordinate = place.coordinate {
                    PlaceSnapshot(coordinate: coordinate)
                        .frame(height: 120)
                }
                HStack(spacing: Spacing.s) {
                    Image(.folioPlace).foregroundStyle(.accent).accessibilityHidden(true)
                    PlaceRowLabel(name: place.name, detail: place.address)
                    Spacer(minLength: 0)
                    Image(systemName: place.hasCoordinate ? "chevron.right" : "arrow.up.right")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.inkTertiary)
                        .accessibilityHidden(true)
                }
                .padding(Spacing.s)
            }
            .clipShape(.rect(cornerRadius: Radius.card))
            .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
            .contentShape(.rect(cornerRadius: Radius.card))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Place, \(place.name)\(place.address.map { ", \($0)" } ?? "")"))
        .accessibilityHint(place.hasCoordinate ? "Shows it on a map" : "Opens Maps")
        .accessibilityIdentifier("entry.place")
        .sheet(isPresented: $showsMap) { PlaceMapSheet(place: place) }
    }
}
