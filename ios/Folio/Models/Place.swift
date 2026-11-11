import CoreLocation
import Foundation

/// Where an entry was written (Batch N). Only ever added by the person — never automatically.
/// Stored inside the encrypted entry payload; coordinates are optional because the web app can
/// add a place by name alone (it has no map search without a third party, DECISIONS 304).
nonisolated struct Place: Codable, Equatable, Hashable, Sendable {
    var name: String
    /// A short, one-line address ("Shoreditch, London"), or nil.
    var address: String?
    var latitude: Double?
    var longitude: Double?

    static let maximumNameLength = 120
    static let maximumAddressLength = 200

    init(name: String, address: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    init(name: String, address: String?, coordinate: CLLocationCoordinate2D) {
        self.init(name: name, address: address, latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasCoordinate: Bool { coordinate != nil }

    /// A clean copy, or nil when there's no name: text trimmed and cut to length, coordinates
    /// kept only when both are finite and on the globe. Synced places pass through this, so a
    /// crafted record can't put junk on a map.
    func validated() -> Place? {
        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumNameLength))
        guard !cleanName.isEmpty else { return nil }
        let cleanAddress = address.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumAddressLength)) }
        var place = Place(name: cleanName, address: cleanAddress?.isEmpty == false ? cleanAddress : nil)
        if let latitude, let longitude, latitude.isFinite, longitude.isFinite,
           (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude) {
            place.latitude = latitude
            place.longitude = longitude
        }
        return place
    }

    /// The name and address on one line, for search and the PDF.
    var line: String { [name, address].compactMap(\.self).joined(separator: " · ") }

    /// Apple Maps for this place: a pin at its coordinate, or a search by name.
    var mapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        var items = [URLQueryItem(name: "q", value: name)]
        if let latitude, let longitude {
            items.append(URLQueryItem(name: "ll", value: String(format: "%.6f,%.6f", latitude, longitude)))
        }
        components.queryItems = items
        return components.url!
    }

    /// Same place, ignoring tiny coordinate differences (recent places, the photo offer).
    func isSame(as other: Place) -> Bool {
        guard name.caseInsensitiveCompare(other.name) == .orderedSame else { return false }
        guard let a = coordinate, let b = other.coordinate else { return coordinate == nil && other.coordinate == nil }
        return abs(a.latitude - b.latitude) < 0.0005 && abs(a.longitude - b.longitude) < 0.0005
    }
}
