import Foundation
import Testing
@testable import FolioCrypto

@Suite("Record encryption round trips and tamper detection")
struct RecordCipherTests {
    let key = DataKey.generate()
    let recordID = UUID()
    let userID = UUID()
    let plaintext = Data(#"{"title":"Secret","bodyMarkdown":"Only I can read this."}"#.utf8)

    func sealed() throws -> SealedRecord {
        try RecordCipher.seal(plaintext, recordID: recordID, type: .entry, userID: userID, using: key)
    }

    @Test("Seal then open returns the plaintext")
    func roundTrip() throws {
        let box = try sealed()
        #expect(box.nonce.count == 12)
        #expect(box.ciphertextAndTag.count == plaintext.count + 16)
        #expect(try RecordCipher.open(box, recordID: recordID, type: .entry, userID: userID, using: key) == plaintext)
    }

    @Test("Each write uses a fresh nonce")
    func freshNonces() throws {
        let nonces = try Set((0..<50).map { _ in try sealed().nonce })
        #expect(nonces.count == 50)
    }

    @Test("Any flipped bit in ciphertext, tag or nonce is rejected", arguments: [0, 7, 30, -1])
    func tamperedCiphertext(index: Int) throws {
        let box = try sealed()
        var bytes = box.ciphertextAndTag
        let position = index >= 0 ? index : bytes.count - 1
        bytes[position] ^= 0x01
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try RecordCipher.open(SealedRecord(nonce: box.nonce, ciphertextAndTag: bytes),
                                  recordID: recordID, type: .entry, userID: userID, using: key)
        }
        var nonce = box.nonce
        nonce[0] ^= 0x80
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try RecordCipher.open(SealedRecord(nonce: nonce, ciphertextAndTag: box.ciphertextAndTag),
                                  recordID: recordID, type: .entry, userID: userID, using: key)
        }
    }

    @Test("Ciphertext can't be replayed onto another record, type, user or key")
    func associatedDataBinding() throws {
        let box = try sealed()
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try RecordCipher.open(box, recordID: UUID(), type: .entry, userID: userID, using: key)
        }
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try RecordCipher.open(box, recordID: recordID, type: .task, userID: userID, using: key)
        }
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try RecordCipher.open(box, recordID: recordID, type: .entry, userID: UUID(), using: key)
        }
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try RecordCipher.open(box, recordID: recordID, type: .entry, userID: userID, using: .generate())
        }
    }

    @Test("Truncated input is rejected cleanly")
    func truncated() throws {
        let box = try sealed()
        #expect(throws: FolioCryptoError.invalidLength) {
            try RecordCipher.open(SealedRecord(nonce: box.nonce.prefix(8), ciphertextAndTag: box.ciphertextAndTag),
                                  recordID: recordID, type: .entry, userID: userID, using: key)
        }
        #expect(throws: FolioCryptoError.invalidLength) {
            try RecordCipher.open(SealedRecord(nonce: box.nonce, ciphertextAndTag: box.ciphertextAndTag.prefix(10)),
                                  recordID: recordID, type: .entry, userID: userID, using: key)
        }
    }

    @Test("Data keys must be exactly 32 bytes and survive a raw round trip")
    func dataKeyLength() throws {
        #expect(throws: FolioCryptoError.invalidLength) { try DataKey(rawRepresentation: Data(count: 16)) }
        let raw = key.rawRepresentation
        #expect(raw.count == 32)
        #expect(try DataKey(rawRepresentation: raw) == key)
    }
}
