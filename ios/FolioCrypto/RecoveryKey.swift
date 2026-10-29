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

    /// Two balanced lines of 13 characters, each grouped 4-5-4, e.g. `B8BW-7T82H-D6ZD` and
    /// `89GF-SE9PB-CF84` — the last group is the 4 characters typed to confirm (Batch F).
    public var displayLines: [String] {
        let characters = Array(string)
        return [characters[..<13], characters[13...]].map { line in
            [line.prefix(4), line.dropFirst(4).prefix(5), line.dropFirst(9)].map { String($0) }.joined(separator: "-")
        }
    }

    /// Both lines joined with hyphens, e.g. `B8BW-7T82H-D6ZD-89GF-SE9PB-CF84`.
    public var displayString: String { displayLines.joined(separator: "-") }

    /// The last four characters, which the person types to confirm they saved the key.
    public var confirmationSuffix: String { String(string.suffix(4)) }
}
