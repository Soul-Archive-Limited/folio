import Foundation

/// Request and response shapes of `/api/auth`, `/api/account`, `/api/keys` and `/api/link`
/// (api/src/routes). Field names match the Worker's JSON exactly.
nonisolated enum AccountAPI {
    struct SignIn: Decodable, Sendable {
        let token: String
        let sessionId: String
        let userId: UUID
        let isNew: Bool
        let hasRecoveryKey: Bool
    }

    struct Reauthenticated: Decodable, Sendable {
        let reauthenticated: Bool
    }

    struct AppleNative: Encodable, Sendable {
        let identityToken: String
        let rawNonce: String
        let authorizationCode: String?
        let deviceName: String
        let reauth: Bool
    }

    struct EmailStart: Encodable, Sendable {
        let email: String
        let client = "ios"
    }

    struct EmailVerify: Encodable, Sendable {
        let email: String
        let code: String
        let client = "ios"
        let deviceName: String
        let reauth: Bool
    }

    struct Exchange: Encodable, Sendable {
        let code: String
        let verifier: String
        let deviceName: String
        let reauth: Bool
    }

    struct Me: Decodable, Sendable, Equatable {
        let userId: UUID
        let sessionId: String
        let email: String?
        let createdAt: Double
        let providers: [String]
        let hasRecoveryKey: Bool
    }

    struct Device: Decodable, Sendable, Identifiable, Equatable {
        let id: String
        let name: String
        let platform: String
        let createdAt: Double
        let lastSeenAt: Double
        let current: Bool
        /// The person's own name for it, sealed with the Data Key; nil = the model name.
        let label: SealedText?
    }

    /// Base64 of AES-GCM ciphertext ‖ tag, and of the 12-byte nonce.
    struct SealedText: Codable, Sendable, Equatable {
        let ciphertext: String
        let nonce: String
    }

    struct DeviceLabel: Encodable, Sendable {
        let label: SealedText?
    }

    struct DeviceName: Encodable, Sendable {
        let name: String
    }

    struct Devices: Decodable, Sendable {
        let devices: [Device]
    }

    struct RecoveryEnvelope: Codable, Sendable {
        /// Base64 of `KeyEnvelope.wireData`.
        let envelope: String
        var replace: Bool?
    }

    struct LinkCreate: Encodable, Sendable {
        /// Base64 of the 32-byte X25519 public key.
        let publicKey: String
    }

    struct LinkCreated: Decodable, Sendable {
        let id: String
        let expiresAt: Double
    }

    /// `GET /link/:id` from the requesting device: waiting, or the sealed Data Key.
    struct LinkStatus: Decodable, Sendable {
        let status: String?
        let senderPublicKey: String?
        let envelope: String?
        let nonce: String?
    }

    /// `GET /link/:id` from the approving device: who is asking.
    struct LinkRequest: Decodable, Sendable {
        let id: String
        let publicKey: String
        let deviceName: String
        let platform: String
    }

    struct LinkApprove: Encodable, Sendable {
        let senderPublicKey: String
        let envelope: String
        let nonce: String
    }

    struct DeleteAccount: Encodable, Sendable {
        let confirm = "DELETE"
    }
}
