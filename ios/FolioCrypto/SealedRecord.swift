import Foundation

/// An encrypted record as it travels to the server: a 96-bit nonce plus ciphertext with
/// the 128-bit GCM tag appended (`ciphertext ‖ tag`), matching WebCrypto's output.
public struct SealedRecord: Equatable, Codable, Sendable {
    public let nonce: Data
    public let ciphertextAndTag: Data

    public init(nonce: Data, ciphertextAndTag: Data) {
        self.nonce = nonce
        self.ciphertextAndTag = ciphertextAndTag
    }
}
