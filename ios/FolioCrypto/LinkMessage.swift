import Foundation

/// What the signed-in device sends (via the server) to a device being linked by QR:
/// its ephemeral public key and the Data Key sealed to the shared secret (SPEC §10.4).
public struct LinkMessage: Equatable, Codable, Sendable {
    public let senderPublicKey: Data
    public let nonce: Data
    public let ciphertextAndTag: Data

    public init(senderPublicKey: Data, nonce: Data, ciphertextAndTag: Data) {
        self.senderPublicKey = senderPublicKey
        self.nonce = nonce
        self.ciphertextAndTag = ciphertextAndTag
    }
}
