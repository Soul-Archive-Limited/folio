import Foundation
import Testing
@testable import FolioCrypto

@Suite("Recovery key and device linking")
struct RecoveryAndLinkTests {
    let userID = UUID()

    @Test("Recovery keys are 26 characters in groups of four")
    func format() {
        let key = RecoveryKey.generate()
        #expect(key.string.count == 26)
        #expect(key.displayString.count == 26 + 5)
        #expect(key.displayString.split(separator: "-").map(\.count) == [4, 5, 4, 4, 5, 4])
        #expect(key.displayLines.count == 2 && key.displayLines.allSatisfy { $0.count == 15 })
        #expect(key.displayLines[1].hasSuffix(key.confirmationSuffix))
        #expect(key.confirmationSuffix == String(key.string.suffix(4)))
        #expect(RecoveryKey.generate() != key)
    }

    @Test("Parsing is forgiving about case, spaces, hyphens and look-alike letters")
    func lenientParsing() throws {
        let key = RecoveryKey.generate()
        let typed = key.displayString.lowercased().replacing("-", with: " ")
        #expect(try RecoveryKey(string: typed) == key)
        let original = try RecoveryKey(string: "0000-0000-0000-0000-0000-0000-00")
        #expect(try RecoveryKey(string: "oooo oooo oooo oooo oooo oooo oo") == original)
    }

    @Test("Malformed recovery keys are rejected", arguments: ["", "TOO-SHORT", "UUUU-UUUU-UUUU-UUUU-UUUU-UUUU-UU", "ZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZ"])
    func malformed(text: String) {
        #expect(throws: FolioCryptoError.malformedRecoveryKey) { try RecoveryKey(string: text) }
    }

    @Test("Wrapping with the recovery key round-trips; the wrong key or user fails")
    func envelope() throws {
        let dataKey = DataKey.generate()
        let recovery = RecoveryKey.generate()
        let envelope = try RecoveryKeyWrapper.wrap(dataKey, with: recovery, userID: userID)
        #expect(try RecoveryKeyWrapper.unwrap(envelope, with: recovery, userID: userID) == dataKey)
        #expect(throws: FolioCryptoError.wrongRecoveryKey) {
            try RecoveryKeyWrapper.unwrap(envelope, with: .generate(), userID: userID)
        }
        #expect(throws: FolioCryptoError.wrongRecoveryKey) {
            try RecoveryKeyWrapper.unwrap(envelope, with: recovery, userID: UUID())
        }
        var tampered = envelope.ciphertextAndTag
        tampered[3] ^= 0xFF
        #expect(throws: FolioCryptoError.wrongRecoveryKey) {
            try RecoveryKeyWrapper.unwrap(KeyEnvelope(salt: envelope.salt, nonce: envelope.nonce, ciphertextAndTag: tampered),
                                          with: recovery, userID: userID)
        }
        #expect(throws: FolioCryptoError.unsupportedVersion) {
            try RecoveryKeyWrapper.unwrap(KeyEnvelope(version: 2, salt: envelope.salt, nonce: envelope.nonce,
                                                      ciphertextAndTag: envelope.ciphertextAndTag), with: recovery, userID: userID)
        }
    }

    @Test("Envelopes encode to JSON and back")
    func envelopeCodable() throws {
        let envelope = try RecoveryKeyWrapper.wrap(.generate(), with: .generate(), userID: userID)
        let decoded = try JSONDecoder().decode(KeyEnvelope.self, from: JSONEncoder().encode(envelope))
        #expect(decoded == envelope)
    }

    @Test("Link handshake delivers the data key; a different request id or user can't open it")
    func link() throws {
        let dataKey = DataKey.generate()
        let requester = DeviceLink.Requester()
        let message = try DeviceLink.sendDataKey(dataKey, toPublicKey: requester.publicKey, requestID: "req-1", userID: userID)
        #expect(try requester.receive(message, requestID: "req-1", userID: userID) == dataKey)
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try requester.receive(message, requestID: "req-2", userID: userID)
        }
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try requester.receive(message, requestID: "req-1", userID: UUID())
        }
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try DeviceLink.Requester().receive(message, requestID: "req-1", userID: userID)
        }
    }

    @Test("Garbage public keys are rejected")
    func badPublicKey() {
        #expect(throws: FolioCryptoError.invalidPublicKey) {
            try DeviceLink.sendDataKey(.generate(), toPublicKey: Data(count: 5), requestID: "r", userID: userID)
        }
    }

    @Test("The envelope's wire form is 93 bytes and round-trips; other versions are refused")
    func envelopeWire() throws {
        let envelope = try RecoveryKeyWrapper.wrap(.generate(), with: .generate(), userID: userID)
        let wire = envelope.wireData
        #expect(wire.count == 93)
        #expect(try KeyEnvelope(wireData: wire) == envelope)
        var future = wire
        future[0] = 2
        #expect(throws: FolioCryptoError.unsupportedVersion) { try KeyEnvelope(wireData: future) }
        #expect(throws: FolioCryptoError.invalidLength) { try KeyEnvelope(wireData: wire.prefix(40)) }
    }

    @Test("A sealed blob's combined form round-trips")
    func combinedBlob() throws {
        let key = DataKey.generate()
        let photo = UUID()
        let sealed = try RecordCipher.seal(Data(repeating: 7, count: 300), recordID: photo, type: .displayBlob, userID: userID, using: key)
        let back = try SealedRecord(combined: sealed.combined)
        #expect(try RecordCipher.open(back, recordID: photo, type: .displayBlob, userID: userID, using: key) == Data(repeating: 7, count: 300))
        #expect(throws: FolioCryptoError.authenticationFailed) {
            try RecordCipher.open(back, recordID: photo, type: .thumbnailBlob, userID: userID, using: key)
        }
    }
}
