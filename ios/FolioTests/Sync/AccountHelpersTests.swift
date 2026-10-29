import FolioCrypto
import Foundation
import Testing
@testable import Folio

@Suite("Sign-in helpers, link payloads and backoff")
struct AccountHelpersTests {
    @Test("PKCE challenge matches RFC 7636's example")
    func pkce() {
        #expect(SignInSecrets.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("Random tokens are 43 base64url characters and differ")
    func tokens() {
        let token = SignInSecrets.randomToken()
        #expect(token.count == 43)
        #expect(token.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        #expect(SignInSecrets.randomToken() != token)
    }

    @Test("The Apple nonce hash is lowercase hex SHA-256")
    func nonce() {
        #expect(SignInSecrets.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("Link payloads round-trip and reject anything else")
    func linkPayload() throws {
        let key = DeviceLink.Requester().publicKey
        let payload = LinkPayload(requestID: UUID().uuidString.lowercased(), publicKey: key)
        #expect(LinkPayload(text: payload.text) == payload)
        #expect(LinkPayload(text: " \(payload.text)\n") == payload)
        #expect(LinkPayload(text: "folio-link:2:\(payload.requestID):\(key.base64URLEncoded)") == nil)
        #expect(LinkPayload(text: "folio-link:1:not-a-uuid:\(key.base64URLEncoded)") == nil)
        #expect(LinkPayload(text: "folio-link:1:\(payload.requestID):\(Data(count: 16).base64URLEncoded)") == nil)
        #expect(LinkPayload(text: "https://example.com") == nil)
    }

    @Test("Backoff grows, stays under 5 minutes, and honours Retry-After")
    func backoff() {
        var backoff = SyncBackoff()
        let first = backoff.nextDelay(retryAfter: nil)
        #expect((1...2).contains(first))
        for _ in 0..<20 { _ = backoff.nextDelay(retryAfter: nil) }
        #expect(backoff.nextDelay(retryAfter: nil) <= 300)
        #expect(backoff.nextDelay(retryAfter: 42) == 42)
        backoff.reset()
        #expect(backoff.attempt == 0)
    }

    @Test("Server errors map to plain-language problems")
    func problems() {
        #expect(APIError.offline.signInProblem == .offline)
        #expect(APIError.rateLimited(retryAfter: 60).signInProblem == .tooMany)
        #expect(APIError.server(status: 400, code: "invalid_code").signInProblem == .wrongCode)
        #expect(APIError.server(status: 409, code: "account_deleting").signInProblem == .deleting)
        #expect(APIError.server(status: 403, code: "reauth_mismatch").signInProblem == .reauthMismatch)
        #expect(APIError.server(status: 500, code: nil).isTransient)
        #expect(!APIError.unauthorized.isTransient)
    }

    @Test("A new record's push sends baseVersion as null, not missing (the API requires the key)")
    func pushEncoding() throws {
        let change = SyncWire.Change(id: UUID(), type: "entry", ciphertext: "AA==", nonce: "AA==", clientUpdatedAt: 1, baseVersion: nil, deleted: false)
        let json = try #require(String(data: JSONEncoder.api.encode(change), encoding: .utf8))
        #expect(json.contains("\"baseVersion\":null"))
    }
}
