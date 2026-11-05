import AuthenticationServices
import SwiftUI

/// The three sign-in buttons (SPEC §6.1 step 5, §6.9 guest Account card, §10.6 re-auth),
/// styled to Apple's and Google's brand rules: Apple first, the system button, black in light
/// mode and white in dark; Google white (dark grey in dark mode) with the official "G" and a
/// 1 pt outline. Apple and Google finish here; email asks the parent to show its steps.
struct SyncSignInButtons: View {
    /// Re-authenticate the current session (delete account) instead of signing in.
    var reauth = false
    let onEmail: () -> Void
    /// Apple or Google finished (signed in, or re-authenticated).
    var onDone: () -> Void = {}

    @Environment(AccountModel.self) private var account
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var rawNonce = ""
    @State private var busy = false
    @State private var signedIn = 0
    /// Batch J: Apple or Google said this would be a new account and needs an invite.
    @State private var invitePrompt: InvitePrompt?
    @State private var appleRunner = AppleSignInRunner()

    struct InvitePrompt: Identifiable {
        enum Provider { case apple, google }
        let id = UUID()
        let provider: Provider
        let problem: SignInProblem
    }

    static let height: Double = 50

    var body: some View {
        VStack(spacing: Spacing.s) {
            appleButton
            googleButton
            Button(action: onEmail) {
                Label("Continue with email", systemImage: "envelope")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: Self.height)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.ink)
        }
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
        .overlay { if busy { ProgressView().controlSize(.large) } }
        .folioHaptic(.success, trigger: signedIn)
        .sheet(item: $invitePrompt) { prompt in
            InviteCodeSheet(problem: prompt.problem) { code in
                switch prompt.provider {
                case .google: google(invite: code)
                case .apple: appleWithInvite(code)
                }
            }
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            rawNonce = SignInSecrets.randomToken()
            request.requestedScopes = reauth ? [] : [.email]
            request.nonce = SignInSecrets.sha256Hex(rawNonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                run(provider: .apple) { () throws(APIError) in try await account.signInWithApple(credential, rawNonce: rawNonce, reauth: reauth) }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code != .canceled { show(.failed) }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        // The system button reads its style once; rebuild it when the appearance changes.
        .id(colorScheme)
        .frame(height: Self.height)
        .clipShape(.capsule)
    }

    private var googleButton: some View {
        let dark = colorScheme == .dark
        return Button { google() } label: {
            HStack(spacing: Spacing.s) {
                Image(.googleMark)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("Continue with Google")
                    .font(.body.weight(.medium))
                    .foregroundStyle(dark ? Color(red: 0.89, green: 0.89, blue: 0.89) : Color(red: 0.12, green: 0.12, blue: 0.12))
            }
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(dark ? Color(red: 0.075, green: 0.075, blue: 0.08) : .white, in: .capsule)
            .overlay {
                Capsule().strokeBorder(dark ? Color(red: 0.56, green: 0.57, blue: 0.56) : Color(red: 0.45, green: 0.47, blue: 0.46),
                                       lineWidth: 1)
            }
        }
        .buttonStyle(.pressable)
    }

    private func google(invite: String? = nil) {
        busy = true
        Task {
            defer { busy = false }
            do throws(GoogleSignInError) {
                try await account.signInWithGoogle(using: webAuthenticationSession, reauth: reauth, invite: invite)
                finished()
            } catch .cancelled {
            } catch .api(let error) {
                handle(error.signInProblem, provider: .google)
            } catch {
                show(.failed)
            }
        }
    }

    /// Sign in with Apple again, this time with the invite.
    private func appleWithInvite(_ invite: String) {
        let nonce = SignInSecrets.randomToken()
        Task {
            guard let credential = await appleRunner.run(nonceHash: SignInSecrets.sha256Hex(nonce)) else { return }
            run(provider: .apple) { () throws(APIError) in
                try await account.signInWithApple(credential, rawNonce: nonce, reauth: reauth, invite: invite)
            }
        }
    }

    private func run(provider: InvitePrompt.Provider, _ work: @escaping () async throws(APIError) -> Void) {
        busy = true
        Task {
            defer { busy = false }
            do throws(APIError) {
                try await work()
                finished()
            } catch {
                handle(error.signInProblem, provider: provider)
            }
        }
    }

    private func handle(_ problem: SignInProblem, provider: InvitePrompt.Provider) {
        if problem.needsInvite { invitePrompt = InvitePrompt(provider: provider, problem: problem) } else { show(problem) }
    }

    private func finished() {
        signedIn += 1
        onDone()
    }

    private func show(_ problem: SignInProblem) {
        toasts.show(ToastMessage(text: problem.message, systemImage: "exclamationmark.triangle.fill"))
    }
}

/// "By continuing you agree to the Terms and Privacy Policy" (SPEC §6.1).
struct LegalFooter: View {
    var body: some View {
        Text("By continuing you agree to the [Terms](https://folio.devilsense.com/terms) and [Privacy Policy](https://folio.devilsense.com/privacy).")
            .font(.footnote)
            .foregroundStyle(.inkSecondary)
            .tint(.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
    }
}
