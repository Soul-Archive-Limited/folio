import Foundation

/// What a link QR code carries (SPEC §10.4): the link request id and the new device's
/// X25519 public key. The key comes from the QR, never from the server, so the server can't
/// swap in its own. Text form: `folio-link:1:<request id>:<base64url public key>`.
nonisolated struct LinkPayload: Equatable, Sendable {
    static let prefix = "folio-link:1:"

    let requestID: String
    let publicKey: Data

    var text: String { "\(Self.prefix)\(requestID):\(publicKey.base64URLEncoded)" }

    init(requestID: String, publicKey: Data) {
        self.requestID = requestID
        self.publicKey = publicKey
    }

    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(Self.prefix) else { return nil }
        let parts = trimmed.dropFirst(Self.prefix.count).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, UUID(uuidString: String(parts[0])) != nil,
              let key = Data(base64URLEncoded: String(parts[1])), key.count == 32 else { return nil }
        requestID = String(parts[0]).lowercased()
        publicKey = key
    }
}
