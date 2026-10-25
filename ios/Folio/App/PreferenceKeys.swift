import Foundation

/// Device-only `UserDefaults` keys (SPEC §5: device settings live in `@AppStorage`).
/// Synced settings (name, appearance, …) move to the encrypted Settings record in Phase 2.
enum PreferenceKeys {
    static let displayName = "displayName"
    static let privacyCoverEnabled = "privacyCoverEnabled"
    static let lastGreetingID = "lastGreetingID"
    static let lastBackgroundAt = "lastBackgroundAt"
}
