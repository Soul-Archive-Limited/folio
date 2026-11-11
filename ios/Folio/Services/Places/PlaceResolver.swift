import CoreLocation
import MapKit

/// Turns Apple Maps results into Folio places (Batch N). Uses the iOS 26 address API
/// (`MKMapItem.address`, `addressRepresentations`, `MKReverseGeocodingRequest`; CLGeocoder and
/// MKPlacemark are deprecated there — DECISIONS 304). Every lookup goes to Apple Maps only.
enum PlaceResolver {
    /// A searched place: its own name, a short address under it.
    static func place(from item: MKMapItem) -> Place? {
        let representations = item.addressRepresentations
        guard let name = item.name ?? representations?.cityWithContext ?? item.address?.shortAddress else { return nil }
        let candidates = [item.address?.shortAddress, representations?.cityWithContext]
        let address = candidates.compactMap(\.self).first { $0.caseInsensitiveCompare(name) != .orderedSame }
        return Place(name: name, address: address, coordinate: item.location.coordinate).validated()
    }

    /// Where a coordinate is. Approximate locations (the person allowed only approximate) are
    /// named by their area ("Shoreditch, London"), never a street they may not be on.
    static func place(at location: CLLocation, approximate: Bool) async -> Place? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        if approximate {
            let representations = item.addressRepresentations
            guard let area = representations?.cityWithContext ?? representations?.cityName else { return nil }
            return Place(name: area, address: representations?.regionName, coordinate: location.coordinate).validated()
        }
        guard var place = place(from: item) else { return nil }
        // Keep the coordinate that was asked about, not the address's centre.
        place.latitude = location.coordinate.latitude
        place.longitude = location.coordinate.longitude
        return place
    }

    /// Looks up a completion the person picked from the search list.
    static func place(for completion: MKLocalSearchCompletion) async -> Place? {
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        guard let item = try? await search.start().mapItems.first else { return nil }
        guard var place = place(from: item) else { return nil }
        // The name the person tapped reads best ("Tate Modern", not "Bankside").
        if !completion.title.isEmpty { place.name = String(completion.title.prefix(Place.maximumNameLength)) }
        return place
    }

    /// Apple Maps for a stored place: a pin at its coordinate, else a search by name.
    @MainActor static func openInMaps(_ place: Place) {
        if let coordinate = place.coordinate {
            let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                                 address: place.address.flatMap { MKAddress(fullAddress: $0, shortAddress: $0) })
            item.name = place.name
            item.openInMaps()
        } else {
            UIApplication.shared.open(place.mapsURL)
        }
    }
}
