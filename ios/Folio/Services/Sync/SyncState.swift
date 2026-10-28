import Foundation

/// Per-account sync bookkeeping kept on this device: the pull cursor and when the last sync
/// finished. Not secret (a number and a date), so `UserDefaults`.
nonisolated enum SyncState {
    static func cursor(for userID: UUID) -> Int64 {
        Int64(UserDefaults.standard.integer(forKey: key("cursor", userID)))
    }

    static func setCursor(_ cursor: Int64, for userID: UUID) {
        UserDefaults.standard.set(Int(cursor), forKey: key("cursor", userID))
    }

    static func lastSynced(for userID: UUID) -> Date? {
        UserDefaults.standard.object(forKey: key("lastSynced", userID)) as? Date
    }

    static func setLastSynced(_ date: Date, for userID: UUID) {
        UserDefaults.standard.set(date, forKey: key("lastSynced", userID))
    }

    static func clear(for userID: UUID) {
        UserDefaults.standard.removeObject(forKey: key("cursor", userID))
        UserDefaults.standard.removeObject(forKey: key("lastSynced", userID))
    }

    private static func key(_ name: String, _ userID: UUID) -> String {
        "sync.\(name).\(userID.uuidString.lowercased())"
    }
}

/// Exponential backoff with jitter (SPEC §10.5), honouring `Retry-After`.
nonisolated struct SyncBackoff: Sendable {
    private(set) var attempt = 0

    mutating func reset() { attempt = 0 }

    /// The wait before the next try: 2, 4, 8 … seconds up to 5 minutes, times 0.5–1.0.
    mutating func nextDelay(retryAfter: TimeInterval?) -> TimeInterval {
        attempt += 1
        if let retryAfter, retryAfter > 0 { return min(retryAfter, 3600) }
        let base = min(pow(2, Double(attempt)), 300)
        return base * Double.random(in: 0.5...1.0)
    }
}
