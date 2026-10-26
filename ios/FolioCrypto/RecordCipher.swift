import CryptoKit
import Foundation

/// AES-256-GCM encryption for records and blobs (SPEC §10.3).
///
/// Associated data binds each ciphertext to its record: `recordId|recordType|userId`
/// (lowercase UUIDs). Moving a ciphertext to another record, type or user makes it fail
/// to decrypt. Every write uses a fresh random nonce.
public enum RecordCipher {
    public static func associatedData(recordID: UUID, type: RecordType, userID: UUID) -> Data {
        Data("\(recordID.uuidString.lowercased())|\(type.rawValue)|\(userID.uuidString.lowercased())".utf8)
    }

    public static func seal(
        _ plaintext: Data, recordID: UUID, type: RecordType, userID: UUID, using key: DataKey
    ) throws(FolioCryptoError) -> SealedRecord {
        try seal(plaintext, recordID: recordID, type: type, userID: userID, using: key, nonce: AES.GCM.Nonce())
    }

    /// Fixed-nonce variant for test vectors only. Production code must use the random-nonce overload.
    static func seal(
        _ plaintext: Data, recordID: UUID, type: RecordType, userID: UUID, using key: DataKey, nonce: AES.GCM.Nonce
    ) throws(FolioCryptoError) -> SealedRecord {
        let aad = associatedData(recordID: recordID, type: type, userID: userID)
        let box = try AESGCM.seal(plaintext, key: key.key, nonce: nonce, aad: aad)
        return SealedRecord(nonce: Data(box.nonce), ciphertextAndTag: AESGCM.ciphertextAndTag(box))
    }

    public static func open(
        _ sealed: SealedRecord, recordID: UUID, type: RecordType, userID: UUID, using key: DataKey
    ) throws(FolioCryptoError) -> Data {
        let aad = associatedData(recordID: recordID, type: type, userID: userID)
        return try AESGCM.open(nonce: sealed.nonce, ciphertextAndTag: sealed.ciphertextAndTag, key: key.key, aad: aad)
    }
}
