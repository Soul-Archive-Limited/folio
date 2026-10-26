import CryptoKit
import Foundation

/// Wraps the Data Key with a key derived from the recovery key (SPEC §10.3–10.4).
///
/// KEK = HKDF-SHA256(recovery key, random 32-byte salt, "folio/recovery-kek/v1").
/// A fast KDF is enough because the recovery key is 128 bits of randomness, not a password.
public enum RecoveryKeyWrapper {
    static let kekInfo = Data("folio/recovery-kek/v1".utf8)
    static let saltByteCount = 32

    static func associatedData(userID: UUID) -> Data {
        Data("folio/dk-envelope/v1|\(userID.uuidString.lowercased())".utf8)
    }

    static func keyEncryptionKey(recoveryKey: RecoveryKey, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: recoveryKey.bytes),
            salt: salt,
            info: kekInfo,
            outputByteCount: 32
        )
    }

    public static func wrap(_ dataKey: DataKey, with recoveryKey: RecoveryKey, userID: UUID) throws(FolioCryptoError) -> KeyEnvelope {
        let salt = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        return try wrap(dataKey, with: recoveryKey, userID: userID, salt: salt, nonce: AES.GCM.Nonce())
    }

    /// Fixed salt/nonce variant for test vectors only.
    static func wrap(
        _ dataKey: DataKey, with recoveryKey: RecoveryKey, userID: UUID, salt: Data, nonce: AES.GCM.Nonce
    ) throws(FolioCryptoError) -> KeyEnvelope {
        let kek = keyEncryptionKey(recoveryKey: recoveryKey, salt: salt)
        let box = try AESGCM.seal(dataKey.rawRepresentation, key: kek, nonce: nonce, aad: associatedData(userID: userID))
        return KeyEnvelope(salt: salt, nonce: Data(box.nonce), ciphertextAndTag: AESGCM.ciphertextAndTag(box))
    }

    public static func unwrap(_ envelope: KeyEnvelope, with recoveryKey: RecoveryKey, userID: UUID) throws(FolioCryptoError) -> DataKey {
        guard envelope.version == KeyEnvelope.currentVersion else { throw .unsupportedVersion }
        guard envelope.salt.count == saltByteCount else { throw .invalidLength }
        let kek = keyEncryptionKey(recoveryKey: recoveryKey, salt: envelope.salt)
        let raw: Data
        do {
            raw = try AESGCM.open(nonce: envelope.nonce, ciphertextAndTag: envelope.ciphertextAndTag, key: kek, aad: associatedData(userID: userID))
        } catch .authenticationFailed {
            throw .wrongRecoveryKey
        }
        return try DataKey(rawRepresentation: raw)
    }
}
