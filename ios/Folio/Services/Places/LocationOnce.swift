import CoreLocation

/// "Current location" in the Place sheet (Batch N): when-in-use permission, asked only the first
/// time it's tapped (after Folio's own explainer), and one location fix — never updates, never
/// in the background. Approximate location is accepted and named by area.
@MainActor
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    enum Failure: Error { case denied, unavailable }

    private let manager = CLLocationManager()
    private var authorization: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var fix: CheckedContinuation<CLLocation, any Error>?

    override init() {
        super.init()
        manager.delegate = self
        // A place, not turn-by-turn: a hundred metres answers quickly and costs little power.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }
    var isApproximate: Bool { manager.accuracyAuthorization == .reducedAccuracy }

    /// Shows the system prompt (only while not determined) and waits for the answer.
    func requestAuthorization() async -> CLAuthorizationStatus {
        guard manager.authorizationStatus == .notDetermined else { return manager.authorizationStatus }
        return await withCheckedContinuation { continuation in
            authorization = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    /// One fix, or `unavailable` after 15 seconds.
    func locate() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: break
        default: throw Failure.denied
        }
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            self?.finish(.failure(Failure.unavailable))
        }
        defer { timeout.cancel() }
        return try await withCheckedThrowingContinuation { continuation in
            fix?.resume(throwing: Failure.unavailable)
            fix = continuation
            manager.requestLocation()
        }
    }

    private func finish(_ result: Result<CLLocation, any Error>) {
        guard let fix else { return }
        self.fix = nil
        fix.resume(with: result)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard status != .notDetermined, let authorization else { return }
            self.authorization = nil
            authorization.resume(returning: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated { finish(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // `locationUnknown` is temporary; Core Location keeps trying until the timeout.
        if (error as? CLError)?.code == .locationUnknown { return }
        MainActor.assumeIsolated { finish(.failure(Failure.unavailable)) }
    }
}
