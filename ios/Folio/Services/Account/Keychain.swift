import Foundation
import Security

/// The app's Keychain items (SPEC §10.2–10.3).
///
/// - The session token is this-device-only and never synced
///   (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
/// - The Data Key and recovery key are synchronizable, so the person's other Apple devices
///   unlock through iCloud Keychain. Synchronizable items can't be "this device only".
///   Both are stored per user id.
nonisolated enum Keychain {
    enum Item: Sendable {
        case session
        case dataKey(userID: UUID)
        case recoveryKey(userID: UUID)

        var account: String {
            switch self {
            case .session: "session"
            case .dataKey(let id): "dk.\(id.uuidString.lowercased())"
            case .recoveryKey(let id): "rk.\(id.uuidString.lowercased())"
            }
        }

        var synchronizable: Bool {
            if case .session = self { false } else { true }
        }

        var accessibility: CFString {
            synchronizable ? kSecAttrAccessibleAfterFirstUnlock : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }

    static let service = "com.devilsense.folio"

    private static func query(_ item: Item) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: item.account,
            kSecAttrSynchronizable: item.synchronizable ? kCFBooleanTrue as Any : kCFBooleanFalse as Any,
        ]
    }

    @discardableResult
    static func set(_ data: Data, for item: Item) -> Bool {
        let base = query(item)
        let update: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: item.accessibility]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var add = base
        add[kSecValueData] = data
        add[kSecAttrAccessible] = item.accessibility
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func data(for item: Item) -> Data? {
        var query = query(item)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Removes the item. For a synchronizable item this removes it from every device in the
    /// person's iCloud Keychain, so only account deletion does that (DECISIONS 182).
    static func delete(_ item: Item) {
        SecItemDelete(query(item) as CFDictionary)
    }

    #if DEBUG
    /// Sync tests only (`-FolioResetAccount`): every Folio item, synchronizable or not.
    static func deleteEverything() {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                       kSecAttrSynchronizable: kSecAttrSynchronizableAny] as CFDictionary)
    }
    #endif
}
