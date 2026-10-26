import CryptoKit
import Foundation

/// QR device linking (SPEC §10.4): X25519 key agreement → HKDF-SHA256 → AES-256-GCM.
///
/// The new device shows its ephemeral public key in a QR code; the signed-in iPhone scans
/// it, so the server never gets a chance to substitute that key. The HKDF info binds both
/// public keys; the salt and associated data bind the request id and user.
public enum DeviceLink {
    static let infoPrefix = Data("folio/link/v1".utf8)

    /// The new device's side: create one per link request and keep it until the reply arrives.
    public struct Requester: Sendable {
        let privateKey: Curve25519.KeyAgreement.PrivateKey

        public init() {
            privateKey = Curve25519.KeyAgreement.PrivateKey()
        }

        init(privateKey: Curve25519.KeyAgreement.PrivateKey) {
            self.privateKey = privateKey
        }

        /// 32 bytes, for the QR code.
        public var publicKey: Data { privateKey.publicKey.rawRepresentation }

        public func receive(_ message: LinkMessage, requestID: String, userID: UUID) throws(FolioCryptoError) -> DataKey {
            let senderKey = try DeviceLink.publicKey(message.senderPublicKey)
            let key = try DeviceLink.linkKey(
                privateKey: privateKey, peerPublicKey: senderKey,
                newDevicePublicKey: publicKey, senderPublicKey: message.senderPublicKey, requestID: requestID
            )
            let raw = try AESGCM.open(
                nonce: message.nonce, ciphertextAndTag: message.ciphertextAndTag, key: key,
                aad: DeviceLink.associatedData(requestID: requestID, userID: userID)
            )
            return try DataKey(rawRepresentation: raw)
        }
    }

    /// The signed-in device's side: seal the Data Key to the public key read from the QR code.
    public static func sendDataKey(
        _ dataKey: DataKey, toPublicKey newDevicePublicKey: Data, requestID: String, userID: UUID
    ) throws(FolioCryptoError) -> LinkMessage {
        try sendDataKey(dataKey, toPublicKey: newDevicePublicKey, requestID: requestID, userID: userID,
                        ephemeralKey: Curve25519.KeyAgreement.PrivateKey(), nonce: AES.GCM.Nonce())
    }

    /// Fixed-key/nonce variant for test vectors only.
    static func sendDataKey(
        _ dataKey: DataKey, toPublicKey newDevicePublicKey: Data, requestID: String, userID: UUID,
        ephemeralKey: Curve25519.KeyAgreement.PrivateKey, nonce: AES.GCM.Nonce
    ) throws(FolioCryptoError) -> LinkMessage {
        let peer = try publicKey(newDevicePublicKey)
        let senderPublicKey = ephemeralKey.publicKey.rawRepresentation
        let key = try linkKey(privateKey: ephemeralKey, peerPublicKey: peer,
                              newDevicePublicKey: newDevicePublicKey, senderPublicKey: senderPublicKey, requestID: requestID)
        let box = try AESGCM.seal(dataKey.rawRepresentation, key: key, nonce: nonce,
                                  aad: associatedData(requestID: requestID, userID: userID))
        return LinkMessage(senderPublicKey: senderPublicKey, nonce: Data(box.nonce), ciphertextAndTag: AESGCM.ciphertextAndTag(box))
    }

    static func associatedData(requestID: String, userID: UUID) -> Data {
        Data("folio/link/v1|\(requestID)|\(userID.uuidString.lowercased())".utf8)
    }

    static func publicKey(_ raw: Data) throws(FolioCryptoError) -> Curve25519.KeyAgreement.PublicKey {
        do { return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw) } catch { throw .invalidPublicKey }
    }

    static func linkKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey, peerPublicKey: Curve25519.KeyAgreement.PublicKey,
        newDevicePublicKey: Data, senderPublicKey: Data, requestID: String
    ) throws(FolioCryptoError) -> SymmetricKey {
        let shared: SharedSecret
        do { shared = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey) } catch { throw .invalidPublicKey }
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(requestID.utf8),
            sharedInfo: infoPrefix + newDevicePublicKey + senderPublicKey,
            outputByteCount: 32
        )
    }
}
