import MapKit
import SwiftUI

/// The Journal's Places view (Batch N): every page with a mapped place, as pins that gather
/// into clusters when they crowd; tap a pin to open its page, a cluster to zoom in. Below, the
/// places as a list (also the VoiceOver route), each one centring the map.
struct JournalPlacesView: View {
    @Bindable var model: JournalModel

    @Environment(DiaryStore.self) private var store
    @State private var focus: PlacesFocus?

    var body: some View {
        let entries = model.placeEntries(store: store)
        if entries.isEmpty {
            EmptyStateView(systemImage: "map",
                           message: "No places yet. Add one with the Place button when you write a page.")
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else {
            VStack(alignment: .leading, spacing: Spacing.m) {
                PlacesMapView(pins: entries.compactMap(PlacePin.init), focus: focus) { model.path.append($0) }
                    .containerRelativeFrame(.vertical) { height, _ in max(height * 0.58, 280) }
                    .clipShape(.rect(cornerRadius: Radius.card))
                    .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(.hairline, lineWidth: 1) }
                    .accessibilityLabel("Map of your places")
                    .accessibilityIdentifier("journal.placesMap")
                ForEach(PlaceGroup.groups(of: entries)) { group in
                    Button { focus = PlacesFocus(coordinate: group.coordinate) } label: {
                        HStack(spacing: Spacing.s) {
                            Image(.folioPlace).foregroundStyle(.accent).accessibilityHidden(true)
                            PlaceRowLabel(name: group.name, detail: group.detail)
                            Spacer(minLength: 0)
                            Text(group.count == 1 ? "1 page" : "\(group.count) pages")
                                .folioFont(.caption).foregroundStyle(.inkSecondary)
                        }
                        .padding(Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .folioGlass(in: .rect(cornerRadius: Radius.card), behindContent: true)
                        .contentShape(.rect(cornerRadius: Radius.card))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityHint("Shows it on the map")
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
        }
    }
}

struct PlacesFocus: Equatable {
    let coordinate: CLLocationCoordinate2D
    let id = UUID()
    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
}

/// One page on the map.
struct PlacePin: Equatable {
    let entryID: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String

    init?(_ entry: Entry) {
        guard let place = entry.place, let coordinate = place.coordinate else { return nil }
        entryID = entry.id
        self.coordinate = coordinate
        title = entry.title.isEmpty ? place.name : entry.title
        let date = entry.day?.utcDate.formatted(Date.FormatStyle(timeZone: .gmt).day().month(.abbreviated).year()) ?? ""
        subtitle = entry.title.isEmpty ? date : "\(place.name) · \(date)"
    }

    static func == (a: Self, b: Self) -> Bool {
        a.entryID == b.entryID && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude && a.title == b.title && a.subtitle == b.subtitle
    }
}

/// Pages at the same place, for the list under the map.
struct PlaceGroup: Identifiable {
    let name: String
    let detail: String?
    let coordinate: CLLocationCoordinate2D
    let count: Int
    var id: String { "\(name)|\(coordinate.latitude)|\(coordinate.longitude)" }

    static func groups(of entries: [Entry]) -> [PlaceGroup] {
        var groups: [(place: Place, count: Int)] = []
        for entry in entries {
            guard let place = entry.place, place.hasCoordinate else { continue }
            if let index = groups.firstIndex(where: { $0.place.isSame(as: place) }) { groups[index].count += 1 } else { groups.append((place, 1)) }
        }
        return groups.compactMap { group in
            group.place.coordinate.map { PlaceGroup(name: group.place.name, detail: group.place.address, coordinate: $0, count: group.count) }
        }
    }
}

/// MKMapView, for clustering (SwiftUI's `Map` doesn't cluster annotations).
struct PlacesMapView: UIViewRepresentable {
    let pins: [PlacePin]
    let focus: PlacesFocus?
    let onOpen: (UUID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onOpen: onOpen) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.register(EntryPinView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        map.register(PlaceClusterView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        map.showsCompass = true
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onOpen = onOpen
        if context.coordinator.pins != pins {
            context.coordinator.pins = pins
            map.removeAnnotations(map.annotations)
            let annotations = pins.map(EntryAnnotation.init)
            map.addAnnotations(annotations)
            map.showAnnotations(annotations, animated: false)
            if annotations.count == 1 {
                map.setRegion(MKCoordinateRegion(center: annotations[0].coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000), animated: false)
            }
        }
        if let focus, focus != context.coordinator.focus {
            context.coordinator.focus = focus
            map.setRegion(MKCoordinateRegion(center: focus.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500), animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onOpen: (UUID) -> Void
        var pins: [PlacePin] = []
        var focus: PlacesFocus?

        init(onOpen: @escaping (UUID) -> Void) { self.onOpen = onOpen }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            if let cluster = annotation as? MKClusterAnnotation {
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            } else if let entry = annotation as? EntryAnnotation {
                onOpen(entry.entryID)
            }
        }
    }
}

final class EntryAnnotation: NSObject, MKAnnotation {
    let entryID: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(_ pin: PlacePin) {
        entryID = pin.entryID
        coordinate = pin.coordinate
        title = pin.title
        subtitle = pin.subtitle
    }
}

final class EntryPinView: MKMarkerAnnotationView {
    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "folio.entry"
        markerTintColor = UIColor(resource: .accentStrong)
        glyphImage = UIImage(named: "folio.place")
        displayPriority = .defaultHigh
        accessibilityHint = String(localized: "Opens the page")
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

final class PlaceClusterView: MKMarkerAnnotationView {
    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        markerTintColor = UIColor(resource: .accent)
        displayPriority = .required
    }

    override var annotation: (any MKAnnotation)? {
        didSet {
            guard let cluster = annotation as? MKClusterAnnotation else { return }
            let count = cluster.memberAnnotations.count
            glyphText = count > 99 ? "99+" : "\(count)"
            accessibilityLabel = String(localized: "\(count) pages here")
            accessibilityHint = String(localized: "Zooms in")
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
