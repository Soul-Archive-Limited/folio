import Foundation

/// Keeps Folio's page in the iPhone Settings app (Settings.bundle) and the synced settings in
/// step, both ways (SPEC §6.9). Settings writes into our `UserDefaults`; we remember what we
/// last mirrored there, so a value that differs from it was changed in Settings, and anything
/// else that differs came from the app or another device.
@MainActor
struct SystemSettingsBridge {
    enum Key {
        static let theme = "settings.theme"
        static let writingFont = "settings.writingFont"
        static let firstWeekday = "settings.firstWeekday"
        static let mirrored = "settings.mirrored"
    }

    /// The three values as Settings.bundle stores them (first weekday 0 = automatic).
    struct Values: Equatable {
        var theme: String
        var writingFont: String
        var firstWeekday: Int

        init(theme: String, writingFont: String, firstWeekday: Int) {
            self.theme = theme
            self.writingFont = writingFont
            self.firstWeekday = firstWeekday
        }

        init(settings: UserSettings) {
            self.init(theme: settings.appearance, writingFont: settings.writingFont, firstWeekday: settings.firstWeekday ?? 0)
        }

        var dictionary: [String: Any] { ["theme": theme, "writingFont": writingFont, "firstWeekday": firstWeekday] }

        init?(dictionary: [String: Any]?) {
            guard let dictionary, let theme = dictionary["theme"] as? String,
                  let font = dictionary["writingFont"] as? String, let weekday = dictionary["firstWeekday"] as? Int else { return nil }
            self.init(theme: theme, writingFont: font, firstWeekday: weekday)
        }
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// What Settings currently shows, cleaned to values Folio knows.
    var systemValues: Values {
        let theme = defaults.string(forKey: Key.theme).flatMap(AppearancePreference.init(rawValue:))?.rawValue
        let font = defaults.string(forKey: Key.writingFont).flatMap(WritingFont.init(rawValue:))?.rawValue
        let weekday = defaults.integer(forKey: Key.firstWeekday)
        return Values(theme: theme ?? AppearancePreference.system.rawValue,
                      writingFont: font ?? WritingFont.newYork.rawValue,
                      firstWeekday: (1...7).contains(weekday) ? weekday : 0)
    }

    /// Call on launch, on every foreground and after any settings change.
    func reconcile(with store: DiaryStore) {
        let app = Values(settings: store.settings())
        let system = systemValues
        let mirrored = Values(dictionary: defaults.dictionary(forKey: Key.mirrored))
        if let mirrored, system != mirrored, system != app {
            // Changed in the Settings app since we last wrote there.
            store.updateSettings { settings in
                settings.appearance = system.theme
                settings.writingFont = system.writingFont
                settings.firstWeekday = system.firstWeekday == 0 ? nil : system.firstWeekday
            }
            write(system)
        } else if system != app || mirrored != app {
            write(app)
        }
    }

    private func write(_ values: Values) {
        defaults.set(values.theme, forKey: Key.theme)
        defaults.set(values.writingFont, forKey: Key.writingFont)
        defaults.set(values.firstWeekday, forKey: Key.firstWeekday)
        defaults.set(values.dictionary, forKey: Key.mirrored)
    }
}
