import CryptoKit
import Foundation
import Testing
@testable import FolioCrypto

/// CryptoKit must reproduce the WebCrypto vectors byte for byte (SPEC §10.3).
@Suite("Shared crypto vectors")
struct VectorTests {
    let vectors: CryptoVectors

    init() throws {
        vectors = try .load()
    }

    @Test("Record encryption matches WebCrypto")
    func records() throws {
        let key = try DataKey(rawRepresentation: Data(hex: vectors.dataKey))
        for record in vectors.records {
            let recordID = try #require(UUID(uuidString: record.recordId))
            let userID = try #require(UUID(uuidString: record.userId))
            let type = try #require(RecordType(rawValue: record.recordType))
            let sealed = try RecordCipher.seal(
                Data(record.plaintext.utf8), recordID: recordID, type: type, userID: userID,
                using: key, nonce: try AES.GCM.Nonce(data: Data(hex: record.nonce))
            )
            #expect(sealed.ciphertextAndTag.hex == record.ciphertextAndTag)
            let opened = try RecordCipher.open(
                SealedRecord(nonce: Data(hex: record.nonce), ciphertextAndTag: Data(hex: record.ciphertextAndTag)),
                recordID: recordID, type: type, userID: userID, using: key
            )
            #expect(String(decoding: opened, as: UTF8.self) == record.plaintext)
        }
    }

    @Test("Crockford base32 matches the reference encoder")
    func base32() {
        for vector in vectors.base32 {
            #expect(CrockfordBase32.encode(Data(hex: vector.bytes)) == vector.encoded)
            #expect(CrockfordBase32.decode(vector.encoded, byteCount: 16)?.hex == vector.bytes)
        }
    }

    @Test("Recovery key string, KEK and envelope match WebCrypto")
    func recovery() throws {
        let recovery = vectors.recovery
        let key = try RecoveryKey(bytes: Data(hex: recovery.keyBytes))
        #expect(key.string == recovery.keyString)
        #expect(key.displayString == recovery.keyDisplay)
        #expect(try RecoveryKey(string: recovery.keyDisplay) == key)

        let kek = RecoveryKeyWrapper.keyEncryptionKey(recoveryKey: key, salt: Data(hex: recovery.kekSalt))
        #expect(kek.withUnsafeBytes { Data($0) }.hex == recovery.kek)

        let userID = try #require(UUID(uuidString: vectors.records[0].userId))
        let dataKey = try DataKey(rawRepresentation: Data(hex: vectors.dataKey))
        let envelope = try RecoveryKeyWrapper.wrap(
            dataKey, with: key, userID: userID, salt: Data(hex: recovery.kekSalt),
            nonce: try AES.GCM.Nonce(data: Data(hex: recovery.envelope.nonce))
        )
        #expect(envelope.ciphertextAndTag.hex == recovery.envelope.ciphertextAndTag)
        #expect(try RecoveryKeyWrapper.unwrap(envelope, with: key, userID: userID) == dataKey)
    }

    @Test("Device link handshake matches WebCrypto (RFC 7748 keys)")
    func link() throws {
        let link = vectors.link
        let userID = try #require(UUID(uuidString: link.userId))
        let requester = DeviceLink.Requester(
            privateKey: try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(hex: link.newDevicePrivateKey))
        )
        #expect(requester.publicKey.hex == link.newDevicePublicKey)

        let dataKey = try DataKey(rawRepresentation: Data(hex: vectors.dataKey))
        let message = try DeviceLink.sendDataKey(
            dataKey, toPublicKey: requester.publicKey, requestID: link.requestId, userID: userID,
            ephemeralKey: try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(hex: link.senderPrivateKey)),
            nonce: try AES.GCM.Nonce(data: Data(hex: link.nonce))
        )
        #expect(message.senderPublicKey.hex == link.senderPublicKey)
        #expect(message.ciphertextAndTag.hex == link.ciphertextAndTag)
        #expect(try requester.receive(message, requestID: link.requestId, userID: userID) == dataKey)
    }
}
