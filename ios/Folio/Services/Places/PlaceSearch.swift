import MapKit

/// Autocomplete for the Place sheet (Batch N): `MKLocalSearchCompleter` with points of interest
/// and addresses. Typed text goes to Apple Maps only while the sheet is open.
@Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                completer.cancel()
                completions = []
                failed = false
            } else {
                completer.queryFragment = trimmed
            }
        }
    }
    private(set) var completions: [MKLocalSearchCompletion] = []
    private(set) var failed = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    /// `near`: a coordinate to lean results towards (the last place used) — without one, Apple
    /// Maps answers worldwide and "Tate M" found Florida first. Nothing about the device's own
    /// location is used here.
    init(near: CLLocationCoordinate2D? = nil) {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
        if let near {
            completer.region = MKCoordinateRegion(center: near, latitudinalMeters: 600_000, longitudinalMeters: 600_000)
        }
    }

    nonisolated func completerDidUpdateResults(_: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            completions = Array(self.completer.results.prefix(8))
            failed = false
        }
    }

    nonisolated func completer(_: MKLocalSearchCompleter, didFailWithError _: any Error) {
        MainActor.assumeIsolated {
            completions = []
            failed = true
        }
    }
}
