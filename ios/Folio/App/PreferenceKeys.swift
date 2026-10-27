import Foundation

/// Device-only `UserDefaults` keys (SPEC §5: device settings live in `@AppStorage`).
/// Synced settings (name, appearance, …) live in the `UserSettings` record instead.
enum PreferenceKeys {
    static let privacyCoverEnabled = "privacyCoverEnabled"
    static let lastGreetingID = "lastGreetingID"
    static let lastBackgroundAt = "lastBackgroundAt"
    /// Profile → Writing → "Show photo tiles on calendar" (SPEC §6.9).
    static let showPhotoTiles = "showPhotoTiles"
    /// To-do: whether the Completed section is expanded (SPEC §6.7, "state persisted").
    static let todoCompletedExpanded = "todoCompletedExpanded"
    /// Onboarding (SPEC §6.1) has been completed or skipped on this device.
    static let hasOnboarded = "hasOnboarded"
    /// Dictation language as a locale identifier; empty follows the device (SPEC §8).
    static let dictationLocale = "dictationLocale"
    /// DEBUG only: pretend Apple's on-device model is unavailable (SPEC §9 testing).
    static let fakeIntelligenceUnavailable = "FolioFakeIntelligenceUnavailable"
}
