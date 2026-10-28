import Foundation
import os

/// DEBUG counter for the request budget (SPEC §10.5: ≤ 10 Worker requests per active user per
/// day on average). Logs the running count for today; Release builds count nothing.
nonisolated enum RequestBudget {
    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "budget")

    static func count() {
        #if DEBUG
        let defaults = UserDefaults.standard
        let day = Date.now.formatted(.iso8601.year().month().day())
        let key = "FolioRequestBudget.\(day)"
        let total = defaults.integer(forKey: key) + 1
        defaults.set(total, forKey: key)
        logger.debug("Worker requests today: \(total, privacy: .public)")
        #endif
    }

    /// Today's count (DEBUG); 0 in Release.
    static var today: Int {
        #if DEBUG
        let day = Date.now.formatted(.iso8601.year().month().day())
        return UserDefaults.standard.integer(forKey: "FolioRequestBudget.\(day)")
        #else
        return 0
        #endif
    }
}
