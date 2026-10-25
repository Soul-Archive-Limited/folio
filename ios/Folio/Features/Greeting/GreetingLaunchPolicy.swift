import Foundation

/// Decides whether a cold launch shows the greeting (SPEC §4.2): skipped when the app was
/// last in the foreground less than 10 minutes ago.
enum GreetingLaunchPolicy {
    static let resumeWindow: TimeInterval = 10 * 60

    static func shouldShow(now: Date, lastBackgroundAt: Date?) -> Bool {
        guard let lastBackgroundAt else { return true }
        return now.timeIntervalSince(lastBackgroundAt) >= resumeWindow
    }
}
