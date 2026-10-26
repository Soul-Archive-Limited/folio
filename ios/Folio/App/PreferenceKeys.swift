import Foundation

/// Device-only `UserDefaults` keys (SPEC §5: device settings live in `@AppStorage`).
/// Synced settings (name, appearance, …) live in the `UserSettings` record instead.
enum PreferenceKeys {
    static let privacyCoverEnabled = "privacyCoverEnabled"
    static let lastGreetingID = "lastGreetingID"
    static let lastBackgroundAt = "lastBackgroundAt"
}
