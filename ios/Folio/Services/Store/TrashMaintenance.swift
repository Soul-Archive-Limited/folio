import BackgroundTasks
import UIKit

/// Runs the Recently Deleted purge (SPEC §5.2) on launch, on foreground and in background
/// refresh. The store's files use `NSFileProtectionComplete`, so it only runs while protected
/// data is available; a locked device just catches up next time (DECISIONS 100).
enum TrashMaintenance {
    /// Shared with Phase 10's background sync.
    static let refreshTaskID = "com.devilsense.folio.refresh"

    static func purgeIfPossible(_ store: DiaryStore) {
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        store.purgeExpiredTrash()
    }

    /// Asks for a background refresh — in about an hour when signed in (sync), a day otherwise
    /// (the purge); the system decides when.
    static func scheduleRefresh(signedIn: Bool = false) {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(signedIn ? 60 * 60 : 24 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Unavailable in the Simulator and when Background App Refresh is off; the
            // foreground purge covers it.
        }
    }
}
