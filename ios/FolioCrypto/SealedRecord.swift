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

extension SealedRecord {
    /// `nonce ‖ ciphertext ‖ tag` in one buffer: the layout of an encrypted photo in R2.
    public var combined: Data { nonce + ciphertextAndTag }

    public init(combined data: Data) throws(FolioCryptoError) {
        guard data.count >= AESGCM.nonceByteCount + AESGCM.tagByteCount else { throw .invalidLength }
        let bytes = [UInt8](data)
        self.init(nonce: Data(bytes[..<AESGCM.nonceByteCount]), ciphertextAndTag: Data(bytes[AESGCM.nonceByteCount...]))
    }
}
