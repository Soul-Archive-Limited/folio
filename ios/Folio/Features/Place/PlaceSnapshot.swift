import MapKit
import OSLog
import SwiftUI

/// A still map of a place (Batch N), drawn by `MKMapSnapshotter` off the main thread and cached
/// by coordinate, size and appearance — cards scroll past dozens of these.
struct PlaceSnapshot: View {
    let coordinate: CLLocationCoordinate2D
    var span: CLLocationDegrees = 0.01
    var showsPin = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(Color.hairline.opacity(0.5))
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .transition(.opacity)
                }
                if showsPin {
                    Image(.folioPlace)
                        .font(.system(size: min(proxy.size.height * 0.32, 22), weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.accentStrong))
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .task(id: key(for: proxy.size)) { await render(size: proxy.size) }
        }
        .accessibilityHidden(true)
    }

    private func key(for size: CGSize) -> String {
        String(format: "%.5f,%.5f,%.0fx%.0f,%.4f,%@,%.0f", coordinate.latitude, coordinate.longitude,
               size.width, size.height, span, colorScheme == .dark ? "d" : "l", displayScale)
    }

    private func render(size: CGSize) async {
        guard size.width > 1, size.height > 1 else { return }
        let key = key(for: size)
        if let cached = PlaceSnapshotCache.shared.image(for: key) {
            image = cached
            return
        }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
        options.size = size
        options.scale = displayScale
        options.traitCollection = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration
        // Held for the whole render: a released snapshotter cancels itself.
        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await snapshotter.start()
            withExtendedLifetime(snapshotter) {}
        } catch {
            PlaceSnapshotCache.logger.debug("Map snapshot failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        PlaceSnapshotCache.shared.store(snapshot.image, for: key)
        withAnimation(.easeOut(duration: 0.2)) { image = snapshot.image }
    }
}

@MainActor
final class PlaceSnapshotCache {
    static let shared = PlaceSnapshotCache()
    static let logger = Logger(subsystem: "com.devilsense.folio", category: "places")
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 120 }
    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func store(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
}

/// The full map for one place, with "Open in Maps" (Batch N).
struct PlaceMapSheet: View {
    let place: Place

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let coordinate = place.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))) {
                        Marker(place.name, image: "folio.place", coordinate: coordinate).tint(.accentStrong)
                    }
                    .mapControls { MapCompass(); MapScaleView() }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    EmptyStateView(systemImage: "map", message: "This place has no map position. Open it in Maps to search for it.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            PlaceRowLabel(name: place.name, detail: place.address)
            Spacer(minLength: Spacing.xs)
            Button("Open in Maps") { PlaceResolver.openInMaps(place) }
                .buttonStyle(.glassProminent).tint(.accentStrong)
                .accessibilityIdentifier("place.openInMaps")
        }
        .padding(Spacing.m)
        .folioGlass(in: .rect(cornerRadius: Radius.card))
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.bottom, Spacing.xs)
    }
}

/// "📍 Tate Modern" — the small place line on cards and in entry detail.
struct PlaceLine: View {
    let place: Place
    var style: FolioTextStyle = .caption

    var body: some View {
        Label {
            Text(place.name).lineLimit(1)
        } icon: {
            Image(.folioPlace).imageScale(.small)
        }
        .labelStyle(PlaceLineLabelStyle())
        .folioFont(style)
        .foregroundStyle(.inkSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Place, \(place.name)"))
    }
}

private struct PlaceLineLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon; configuration.title }
    }
}
