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

extension KeyEnvelope {
    /// The compact form sent to `PUT /api/keys/recovery` (base64 of these bytes):
    /// `version (1 byte) ‖ salt (32) ‖ nonce (12) ‖ ciphertext ‖ tag`. 93 bytes for a 256-bit key.
    public var wireData: Data {
        var data = Data([UInt8(version)])
        data.append(salt)
        data.append(nonce)
        data.append(ciphertextAndTag)
        return data
    }

    public init(wireData data: Data) throws(FolioCryptoError) {
        let bytes = [UInt8](data)
        guard let version = bytes.first else { throw .invalidLength }
        guard Int(version) == KeyEnvelope.currentVersion else { throw .unsupportedVersion }
        let saltEnd = 1 + RecoveryKeyWrapper.saltByteCount
        let nonceEnd = saltEnd + AESGCM.nonceByteCount
        guard bytes.count >= nonceEnd + AESGCM.tagByteCount else { throw .invalidLength }
        self.init(version: Int(version), salt: Data(bytes[1..<saltEnd]), nonce: Data(bytes[saltEnd..<nonceEnd]),
                  ciphertextAndTag: Data(bytes[nonceEnd...]))
    }
}
