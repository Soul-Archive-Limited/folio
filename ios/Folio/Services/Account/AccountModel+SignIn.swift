import AuthenticationServices
import Foundation
import SwiftUI

/// The three ways in (SPEC §10.2). Each can also re-authenticate the current session
/// (`reauth: true`), which delete account needs.
extension AccountModel {
    // MARK: Apple

    /// After `SignInWithAppleButton` succeeds. `rawNonce` is the value whose SHA-256 went to Apple.
    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential, rawNonce: String, reauth: Bool = false,
                         invite: String? = nil) async throws(APIError) {
        guard let tokenData = credential.identityToken, let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw .invalidResponse
        }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let request = AccountAPI.AppleNative(identityToken: identityToken, rawNonce: rawNonce, authorizationCode: code,
                                             deviceName: SignInSecrets.deviceName, reauth: reauth, invite: invite)
        if reauth {
            let _: AccountAPI.Reauthenticated = try await api.send("POST", "auth/apple/native", json: request)
            noteReauthenticated()
        } else {
            let result: AccountAPI.SignIn = try await api.send("POST", "auth/apple/native", json: request)
            completeSignIn(result, appleUserID: credential.user)
        }
    }

    // MARK: Email

    func startEmailSignIn(_ email: String) async throws(APIError) {
        let _: OKResponse = try await api.send("POST", "auth/email/start", json: AccountAPI.EmailStart(email: email))
    }

    func verifyEmailCode(_ code: String, email: String, reauth: Bool = false, invite: String? = nil) async throws(APIError) {
        let request = AccountAPI.EmailVerify(email: email, code: code, deviceName: SignInSecrets.deviceName, reauth: reauth, invite: invite)
        if reauth {
            let _: AccountAPI.Reauthenticated = try await api.send("POST", "auth/email/verify", json: request)
            noteReauthenticated()
        } else {
            let result: AccountAPI.SignIn = try await api.send("POST", "auth/email/verify", json: request)
            completeSignIn(result)
        }
    }

    // MARK: Google

    /// Google through `ASWebAuthenticationSession` with no SDK (DECISIONS 161): the Worker runs
    /// the OAuth dance and hands back a 60-second code bound to this app's verifier.
    func signInWithGoogle(using session: WebAuthenticationSession, reauth: Bool = false, invite: String? = nil) async throws(GoogleSignInError) {
        let verifier = SignInSecrets.randomToken()
        var components = URLComponents(url: api.baseURL.appending(path: "auth/google/start"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "challenge", value: SignInSecrets.challenge(for: verifier)),
        ] + (reauth ? [URLQueryItem(name: "reauth", value: "1")] : [])
          + (invite.map { [URLQueryItem(name: "invite", value: $0)] } ?? [])
        guard let start = components?.url else { throw .failed }

        let callback: URL
        do {
            callback = try await session.authenticate(using: start, callbackURLScheme: "folio")
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw .cancelled
        } catch {
            throw .failed
        }
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard callback.host() == "auth", let code = items.first(where: { $0.name == "code" })?.value else {
            let error = items.first { $0.name == "error" }?.value
            if error == "cancelled" { throw .cancelled }
            // A reason from the Worker (Batch K); a new account without an invite asks for one (Batch J).
            throw .refused(SignInProblem(oauthError: error))
        }

        let request = AccountAPI.Exchange(code: code, verifier: verifier, deviceName: SignInSecrets.deviceName, reauth: reauth)
        do {
            if reauth {
                let _: AccountAPI.Reauthenticated = try await api.send("POST", "auth/exchange", json: request)
                noteReauthenticated()
            } else {
                let result: AccountAPI.SignIn = try await api.send("POST", "auth/exchange", json: request)
                completeSignIn(result)
            }
        } catch .server(_, "invalid_code") {
            // The 60-second hand-off code ran out (or was used): starting again is the fix.
            throw .refused(.expired)
        } catch {
            throw .api(error)
        }
    }
}

enum GoogleSignInError: Error {
    case cancelled, failed
    case refused(SignInProblem)
    case api(APIError)
}
