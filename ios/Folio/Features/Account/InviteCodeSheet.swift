import AuthenticationServices
import SwiftUI

/// The invite field (Batch J): shown only when a sign-in would create a new account.
struct InviteCodeField: View {
    @Binding var code: String

    var body: some View {
        TextField("ABCD-EFGH", text: $code)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .semibold, design: .monospaced))
            .frame(minHeight: 56)
            .folioGlass(in: .rect(cornerRadius: Radius.card))
            .accessibilityLabel("Invite code")
            // Not rewritten while typing (that drops keystrokes): the server reads it forgivingly
            // (case, spaces, dashes, O/0, I/L/1).
    }
}

/// After Apple or Google said the account is new: ask for the invite, then try again.
struct InviteCodeSheet: View {
    let problem: SignInProblem
    let onContinue: (String) -> Void
    @State private var code = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AccountStepLayout(systemImage: "envelope.open", title: "Your invite", subtitle: LocalizedStringKey(String(localized: problem.message))) {
            InviteCodeField(code: $code)
        } actions: {
            Button {
                dismiss()
                onContinue(code)
            } label: {
                Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.emberStrong)
            .disabled(code.filter { $0.isLetter || $0.isNumber }.count != 8)
            Button("Not now") { dismiss() }
                .foregroundStyle(.inkSecondary)
                .frame(minHeight: Spacing.minHitTarget)
        }
        .presentationDetents([.medium])
    }
}

/// Sign in with Apple without the system button (Batch J): used to retry with an invite.
@MainActor
final class AppleSignInRunner: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential?, Never>?

    func run(nonceHash: String) async -> ASAuthorizationAppleIDCredential? {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]
        request.nonce = nonceHash
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        MainActor.assumeIsolated { finish(credential) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        MainActor.assumeIsolated { finish(nil) }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let window = scenes.compactMap(\.keyWindow).first { return window }
            // No key window (shouldn't happen while a sign-in screen is up): a window on the first scene.
            guard let scene = scenes.first else { preconditionFailure("Sign in with Apple needs a window scene") }
            return ASPresentationAnchor(windowScene: scene)
        }
    }

    private func finish(_ credential: ASAuthorizationAppleIDCredential?) {
        continuation?.resume(returning: credential)
        continuation = nil
    }
}
