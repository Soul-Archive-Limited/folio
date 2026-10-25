#if DEBUG
import Foundation

/// DEBUG-only launch arguments for screenshots and UI checks. `UserDefaults` reads
/// `-key value` pairs from the launch arguments automatically.
///
/// - `-FolioScreen gallery|cover|greeting` opens one screen directly.
/// - `-FolioNow 2026-10-26T08:15` fakes the clock (local time).
/// - `-FolioGreetingHold YES` stops the greeting before it dissolves.
/// - `-displayName Sam` sets the name.
enum DebugLaunchOptions {
    enum Screen: String {
        case gallery, cover, greeting
    }

    static var screen: Screen? {
        UserDefaults.standard.string(forKey: "FolioScreen").flatMap(Screen.init(rawValue:))
    }

    static var holdsGreeting: Bool {
        UserDefaults.standard.bool(forKey: "FolioGreetingHold")
    }

    static var fakeNow: Date? {
        guard let value = UserDefaults.standard.string(forKey: "FolioNow") else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: value)
    }
}
#endif
