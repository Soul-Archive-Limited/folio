import Foundation

/// The App Group shared by Folio, its widgets and its share extension (Batch J).
///
/// Only small, local, device-only files live here — the widget snapshot and its thumbnails,
/// the widgets' pending ticks, the share extension's encrypted inbox. Nothing here syncs: the
/// server only ever sees what `SyncEngine` encrypts from the app's own store. Files are written
/// with `completeUntilFirstUserAuthentication`, so widgets can read them after the first
/// unlock since a restart, never before.
nonisolated enum AppGroup {
    static let identifier = "group.com.devilsense.folio"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }

    /// A folder inside the group container, created on first use.
    static func folder(_ name: String) -> URL? {
        guard let url = container?.appending(path: name, directoryHint: .isDirectory) else { return nil }
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                     attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        }
        return url
    }

    /// Atomic write with the widget-readable protection class.
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: Widget settings (Profile → Widgets)

    static let homeDetailsKey = "widgetHomeDetails"
    static let lockDetailsKey = "widgetLockDetails"

    /// Home Screen widgets show titles (default on).
    static var showsHomeDetails: Bool { defaults?.object(forKey: homeDetailsKey) as? Bool ?? true }
    /// Lock Screen widgets show titles (default off: counts only).
    static var showsLockDetails: Bool { defaults?.bool(forKey: lockDetailsKey) ?? false }
}
