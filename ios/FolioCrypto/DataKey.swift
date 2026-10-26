import CryptoKit
import Foundation

/// The 256-bit Data Key (DK) that encrypts every record and photo (SPEC §10.3).
/// Generated on the device at first sign-in; the server only ever holds wrapped copies.
public struct DataKey: Sendable {
    public static let byteCount = 32

    let key: SymmetricKey

    init(key: SymmetricKey) {
        self.key = key
    }

    public static func generate() -> DataKey {
        DataKey(key: SymmetricKey(size: .bits256))
    }

    public init(rawRepresentation: some ContiguousBytes) throws(FolioCryptoError) {
        let key = SymmetricKey(data: rawRepresentation)
        guard key.bitCount == Self.byteCount * 8 else { throw .invalidLength }
        self.key = key
    }

    /// Raw key bytes, for storing in the Keychain only. Never log or persist elsewhere.
    public var rawRepresentation: Data {
        key.withUnsafeBytes { Data($0) }
    }
}

extension DataKey: Equatable {
    /// Constant-time comparison (`SymmetricKey`'s `==`).
    public static func == (lhs: DataKey, rhs: DataKey) -> Bool { lhs.key == rhs.key }
}
