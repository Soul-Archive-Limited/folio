import Foundation

/// A wrapped Data Key as stored on the server (SPEC §10.3). The server can't unwrap it.
public struct KeyEnvelope: Equatable, Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    /// Random HKDF salt, 32 bytes.
    public let salt: Data
    public let nonce: Data
    public let ciphertextAndTag: Data

    public init(version: Int = KeyEnvelope.currentVersion, salt: Data, nonce: Data, ciphertextAndTag: Data) {
        self.version = version
        self.salt = salt
        self.nonce = nonce
        self.ciphertextAndTag = ciphertextAndTag
    }
}
