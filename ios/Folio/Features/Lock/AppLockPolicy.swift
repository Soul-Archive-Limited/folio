import Foundation

/// "Lock after" choices for Lock Folio (Batch J), in seconds away from the app.
nonisolated enum LockAfter: Int, CaseIterable, Identifiable, Sendable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .immediately: String(localized: "Immediately")
        case .oneMinute: String(localized: "After 1 minute")
        case .fiveMinutes: String(localized: "After 5 minutes")
        case .fifteenMinutes: String(localized: "After 15 minutes")
        }
    }

    /// Whether coming back after leaving at `leftAt` needs an unlock. A clock that moved
    /// backwards (time zone travel, a manual change) locks: never trust a negative gap.
    func requiresUnlock(leftAt: Date?, now: Date) -> Bool {
        guard let leftAt else { return true }
        let away = now.timeIntervalSince(leftAt)
        return away < 0 || away >= Double(rawValue)
    }
}
