import FolioCrypto
import Foundation

/// The device being unlocked by QR (SPEC §10.4): makes an ephemeral X25519 key, registers a
/// link request (5 minutes), shows the QR and waits for another signed-in device to send the
/// Data Key sealed to it.
@Observable
final class LinkRequestModel {
    enum Phase: Equatable {
        case starting
        case showing(LinkPayload, expiresAt: Date)
        case expired
        case failed
    }

    private(set) var phase: Phase = .starting
    @ObservationIgnored private var requester = DeviceLink.Requester()
    @ObservationIgnored private let account: AccountModel

    init(account: AccountModel) {
        self.account = account
    }

    /// Registers a request, then polls every 3 s until the key arrives or the request expires.
    /// Returns the Data Key, or nil when cancelled, expired or failed.
    func run() async -> DataKey? {
        requester = DeviceLink.Requester()
        phase = .starting
        let created: AccountAPI.LinkCreated
        do {
            created = try await account.api.send("POST", "link",
                                                  json: AccountAPI.LinkCreate(publicKey: requester.publicKey.base64EncodedString()))
        } catch {
            phase = .failed
            return nil
        }
        let payload = LinkPayload(requestID: created.id, publicKey: requester.publicKey)
        let expiresAt = Date(timeIntervalSince1970: created.expiresAt / 1000)
        phase = .showing(payload, expiresAt: expiresAt)

        while !Task.isCancelled, Date.now < expiresAt {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { break }
            guard let status: AccountAPI.LinkStatus = try? await account.api.send("GET", "link/\(created.id)") else { continue }
            guard status.status == "approved" else { continue }
            if let key = open(status, requestID: created.id) { return key }
            phase = .failed
            return nil
        }
        if Task.isCancelled {
            let _: OKResponse? = try? await account.api.send("DELETE", "link/\(created.id)")
        } else {
            phase = .expired
        }
        return nil
    }

    private func open(_ status: AccountAPI.LinkStatus, requestID: String) -> DataKey? {
        guard let userID = account.userID,
              let sender = status.senderPublicKey.flatMap({ Data(base64Encoded: $0) }),
              let sealed = status.envelope.flatMap({ Data(base64Encoded: $0) }),
              let nonce = status.nonce.flatMap({ Data(base64Encoded: $0) }) else { return nil }
        let message = LinkMessage(senderPublicKey: sender, nonce: nonce, ciphertextAndTag: sealed)
        return try? requester.receive(message, requestID: requestID, userID: userID)
    }
}
