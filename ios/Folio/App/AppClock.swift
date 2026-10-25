import Foundation

/// The app's notion of "now". DEBUG builds accept a fake clock for screenshots and tests:
/// launch with `-FolioNow 2026-10-26T08:15` (local time).
enum AppClock {
    static var now: Date {
        #if DEBUG
        if let override = DebugLaunchOptions.fakeNow { return override }
        #endif
        return .now
    }
}
