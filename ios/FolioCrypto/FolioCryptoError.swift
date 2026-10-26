/// Errors from FolioCrypto. Messages never include key material or plaintext.
public enum FolioCryptoError: Error, Equatable, Sendable {
    /// A key or nonce had the wrong number of bytes.
    case invalidLength
    /// Ciphertext, tag, nonce or associated data didn't verify: tampered, or the wrong key.
    case authenticationFailed
    /// The recovery key text isn't 26 valid Crockford base32 characters.
    case malformedRecoveryKey
    /// The recovery key is well-formed but doesn't unlock this envelope.
    case wrongRecoveryKey
    /// A public key from a link request couldn't be parsed.
    case invalidPublicKey
    /// The envelope uses a version this app doesn't understand.
    case unsupportedVersion
}
