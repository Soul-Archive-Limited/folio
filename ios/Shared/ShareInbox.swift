import CryptoKit
import Foundation
import Security

/// The share extension's inbox (Batch J). Each shared item is sealed with AES-GCM under an
/// inbox key kept in the Keychain, shared through the App Group's access group (this device
/// only, never synced), and written to the App Group; Folio imports and deletes it on its next
/// run. So a backup of the App Group holds only ciphertext. Nothing here goes to the server —
/// once imported, the entry syncs end-to-end encrypted like any other.
nonisolated enum ShareInbox {
    struct Item: Codable, Sendable {
        var id = UUID()
        var createdAt = Date()
        /// "YYYY-MM-DD"
        var dayKey: String
        var categoryID: UUID?
        /// Add to the latest page of that day instead of a new page.
        var appendsToDay: Bool
        var title: String?
        var text: String?
        var link: String?
        /// JPEG, long edge ≤ 2048 (Folio re-processes them: GPS stripped, HEIC).
        var photos: [Data]
    }

    /// What the extension's little composer needs: categories and whether the day has a page.
    struct Context: Codable, Sendable {
        struct Category: Codable, Sendable, Identifiable {
            var id: UUID
            var name: String
            var colorHex: String
        }
        var categories: [Category]
        var defaultCategoryID: UUID?
        /// Days ("YYYY-MM-DD", today and yesterday) that already have a page.
        var daysWithPages: [String]
    }

    static let accessGroup = AppGroup.identifier
    private static let keyAccount = "share.inbox"

    private static var folder: URL? { AppGroup.folder("Inbox") }
    private static var contextURL: URL? { AppGroup.folder("Share")?.appending(path: "context.sealed") }

    // MARK: Key

    /// The inbox key; created on first use by whichever side gets there first.
    static func key() -> SymmetricKey? {
        if let data = readKey() { return SymmetricKey(data: data) }
        let fresh = SymmetricKey(size: .bits256)
        let data = fresh.withUnsafeBytes { Data($0) }
        let add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: "com.devilsense.folio.share", kSecAttrAccount: keyAccount,
            kSecAttrAccessGroup: accessGroup, kSecAttrSynchronizable: kCFBooleanFalse as Any,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, kSecValueData: data,
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        // Lost a race with the other process: use theirs.
        if status == errSecDuplicateItem, let existing = readKey() { return SymmetricKey(data: existing) }
        return status == errSecSuccess ? fresh : nil
    }

    private static func readKey() -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: "com.devilsense.folio.share", kSecAttrAccount: keyAccount,
            kSecAttrAccessGroup: accessGroup, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data, data.count == 32 else { return nil }
        return data
    }

    // MARK: Sealing

    static func seal<T: Encodable>(_ value: T) throws -> Data {
        guard let key = key() else { throw CocoaError(.fileWriteNoPermission) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let sealed = try AES.GCM.seal(encoder.encode(value), using: key).combined else { throw CocoaError(.coderInvalidValue) }
        return sealed
    }

    static func open<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let key = key() else { throw CocoaError(.fileReadNoPermission) }
        let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: plain)
    }

    // MARK: Inbox

    static func add(_ item: Item) throws {
        guard let url = folder?.appending(path: "\(item.id.uuidString).sealed") else { throw CocoaError(.fileNoSuchFile) }
        try AppGroup.write(try seal(item), to: url)
    }

    /// Every waiting item, oldest first; each is passed to `body` and deleted once it returns
    /// true. A file that can't be opened (wrong key after a restore to a new device) is dropped.
    static func drain(_ body: (Item) -> Bool) {
        guard let folder, let names = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        let items = names.filter { $0.pathExtension == "sealed" }.compactMap { url -> (URL, Item?) in
            (url, (try? Data(contentsOf: url)).flatMap { try? open(Item.self, from: $0) })
        }
        for (url, item) in items.sorted(by: { ($0.1?.createdAt ?? .distantPast) < ($1.1?.createdAt ?? .distantPast) }) {
            guard let item else { try? FileManager.default.removeItem(at: url); continue }
            if body(item) { try? FileManager.default.removeItem(at: url) }
        }
    }

    // MARK: Context

    static func writeContext(_ context: Context) {
        guard let url = contextURL, let data = try? seal(context) else { return }
        try? AppGroup.write(data, to: url)
    }

    static func readContext() -> Context? {
        guard let url = contextURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? open(Context.self, from: data)
    }
}
