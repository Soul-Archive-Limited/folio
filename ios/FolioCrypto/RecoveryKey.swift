import CryptoKit
import Foundation

/// The 128-bit recovery key (SPEC §6.13, §10.4), shown as 26 Crockford base32 characters
/// in groups of four. It never leaves the device in any form the server can use.
public struct RecoveryKey: Equatable, Sendable {
    public static let byteCount = 16
    public static let characterCount = 26

    let bytes: Data

    init(bytes: Data) throws(FolioCryptoError) {
        guard bytes.count == Self.byteCount else { throw .invalidLength }
        self.bytes = bytes
    }

    public static func generate() -> RecoveryKey {
        let random = SymmetricKey(size: SymmetricKeySize(bitCount: byteCount * 8)).withUnsafeBytes { Data($0) }
        // Length is fixed above, so this cannot fail.
        guard let key = try? RecoveryKey(bytes: random) else { preconditionFailure("Recovery key must be 16 bytes") }
        return key
    }

    /// Parses what a person typed or pasted (see `CrockfordBase32.decode` for leniency).
    public init(string: String) throws(FolioCryptoError) {
        guard let data = CrockfordBase32.decode(string, byteCount: Self.byteCount) else { throw .malformedRecoveryKey }
        self.bytes = data
    }

    /// 26 characters, no separators.
    public var string: String { CrockfordBase32.encode(bytes) }

    /// Groups of four separated by hyphens, e.g. `B8BW-7T82-HD6Z-D89G-FSE9-PBCF-84`.
    public var displayString: String {
        var groups: [String] = []
        var current = ""
        for character in string {
            current.append(character)
            if current.count == 4 {
                groups.append(current)
                current = ""
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups.joined(separator: "-")
    }

    /// The last four characters, which the person types to confirm they saved the key.
    public var confirmationSuffix: String { String(string.suffix(4)) }
}
