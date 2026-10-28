import FolioCrypto
import Foundation
import LocalAuthentication

/// Approving a link from this (signed-in, unlocked) device: Profile → Link a browser or
/// device → scan → "Allow … to read your diary?" → Face ID → send (SPEC §10.4).
extension AccountModel {
    /// Reads who is asking. Refuses a request whose public key on the server differs from the
    /// QR's (a substituted key), or one from this same session.
    func linkRequest(for payload: LinkPayload) async throws(LinkApprovalError) -> AccountAPI.LinkRequest {
        let request: AccountAPI.LinkRequest
        do throws(APIError) {
            request = try await api.send("GET", "link/\(payload.requestID)")
        } catch .server(404, _), .server(410, _) {
            throw .expired
        } catch {
            throw .network
        }
        guard Data(base64Encoded: request.publicKey) == payload.publicKey else { throw .mismatch }
        return request
    }

    /// Asks for Face ID / the passcode, then sends the Data Key sealed to the QR's key.
    func approveLink(_ payload: LinkPayload, deviceName: String) async throws(LinkApprovalError) {
        guard let dataKey, let userID else { throw .locked }
        try await authenticateOwner(reason: String(localized: "Allow \(deviceName) to read your diary"))
        let message: LinkMessage
        do {
            message = try DeviceLink.sendDataKey(dataKey, toPublicKey: payload.publicKey, requestID: payload.requestID, userID: userID)
        } catch {
            throw .mismatch
        }
        let body = AccountAPI.LinkApprove(senderPublicKey: message.senderPublicKey.base64EncodedString(),
                                          envelope: message.ciphertextAndTag.base64EncodedString(),
                                          nonce: message.nonce.base64EncodedString())
        do throws(APIError) {
            let _: OKResponse = try await api.send("POST", "link/\(payload.requestID)/approve", json: body)
        } catch .server(404, _), .server(410, _), .server(409, _) {
            throw .expired
        } catch {
            throw .network
        }
    }

    /// Face ID, Touch ID or the passcode. A device with no passcode can't do any of these;
    /// the confirmation sheet is then the only check (DECISIONS 183).
    func authenticateOwner(reason: String) async throws(LinkApprovalError) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            throw .notAuthenticated
        }
    }
}

enum LinkApprovalError: Error, Equatable {
    case expired, mismatch, network, locked, notAuthenticated
}
