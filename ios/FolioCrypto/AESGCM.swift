import CryptoKit
import Foundation

/// Thin wrapper over `AES.GCM` that uses the `ciphertext ‖ tag` layout shared with
/// WebCrypto and maps CryptoKit errors to `FolioCryptoError`.
enum AESGCM {
    static let nonceByteCount = 12
    static let tagByteCount = 16

    static func seal(_ plaintext: Data, key: SymmetricKey, nonce: AES.GCM.Nonce, aad: Data) throws(FolioCryptoError) -> AES.GCM.SealedBox {
        do {
            return try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
        } catch {
            throw .invalidLength
        }
    }

    static func open(nonce: Data, ciphertextAndTag: Data, key: SymmetricKey, aad: Data) throws(FolioCryptoError) -> Data {
        guard nonce.count == nonceByteCount, ciphertextAndTag.count >= tagByteCount else { throw .invalidLength }
        do {
            let box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: ciphertextAndTag.dropLast(tagByteCount),
                tag: ciphertextAndTag.suffix(tagByteCount)
            )
            return try AES.GCM.open(box, using: key, authenticating: aad)
        } catch {
            throw .authenticationFailed
        }
    }

    /// `ciphertext ‖ tag` as a fresh, zero-based `Data`. (`box.ciphertext + box.tag` would
    /// keep the slice's non-zero start index and trap on `data[0]`.)
    static func ciphertextAndTag(_ box: AES.GCM.SealedBox) -> Data {
        var output = Data(capacity: box.ciphertext.count + tagByteCount)
        output.append(contentsOf: box.ciphertext)
        output.append(contentsOf: box.tag)
        return output
    }

    static func nonce(_ data: Data) throws(FolioCryptoError) -> AES.GCM.Nonce {
        do { return try AES.GCM.Nonce(data: data) } catch { throw .invalidLength }
    }
}
