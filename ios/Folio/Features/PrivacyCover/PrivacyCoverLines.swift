import Foundation

/// The app-switcher cover's line (SPEC §4.3): a fresh one each time Folio goes to the
/// background, never the same as the last (owner's test, Batch I — it always said "See you
/// soon, Sam"). Each line has a named and an unnamed form, so the pool is the same either way.
enum PrivacyCoverLines {
    static let count = 8
    static let key = "privacyCoverLine"

    static func line(_ index: Int, name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = !name.isEmpty
        switch index % count {
        case 0: return named ? String(localized: "See you soon, \(name).") : String(localized: "See you soon.")
        case 1: return named ? String(localized: "Your pages are safe, \(name).") : String(localized: "Your pages are safe.")
        case 2: return named ? String(localized: "Back whenever you're ready, \(name).") : String(localized: "Back whenever you're ready.")
        case 3: return named ? String(localized: "Your days are kept, \(name).") : String(localized: "Your days are kept.")
        case 4: return named ? String(localized: "Locked away safely, \(name).") : String(localized: "Locked away safely.")
        case 5: return named ? String(localized: "Until next time, \(name).") : String(localized: "Until next time.")
        case 6: return named ? String(localized: "The page will wait for you, \(name).") : String(localized: "The page will wait for you.")
        default: return named ? String(localized: "Only you can read this, \(name).") : String(localized: "Only you can read this.")
        }
    }

    /// A random index other than `last`.
    static func next(after last: Int?, using generator: inout some RandomNumberGenerator) -> Int {
        let choices = (0..<count).filter { $0 != last }
        return choices.randomElement(using: &generator) ?? 0
    }

    /// Picks the next line; called once each time the app leaves the foreground.
    static func advance(defaults: UserDefaults = .standard) {
        var generator = SystemRandomNumberGenerator()
        let last = defaults.object(forKey: key) as? Int
        defaults.set(next(after: last, using: &generator), forKey: key)
    }
}
