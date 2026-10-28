import SwiftUI

/// "Continue with email" (SPEC §6.1 step 5): the address, then the 6-digit code. Used for
/// signing in and for re-authenticating before delete account.
struct EmailSignInFlow: View {
    var reauth = false
    /// Pre-filled for re-authentication (the account's own address).
    var initialEmail = ""
    let onDone: () -> Void
    let onCancel: () -> Void

    @Environment(AccountModel.self) private var account
    @State private var email = ""
    @State private var codeSentAt: Date?
    @State private var problem: SignInProblem?
    @State private var sending = false

    var body: some View {
        Group {
            if let codeSentAt {
                EmailCodeStep(email: email, sentAt: codeSentAt, reauth: reauth, onResend: send, onDone: onDone,
                              onChangeEmail: { self.codeSentAt = nil })
            } else {
                EmailAddressStep(email: $email, problem: problem, sending: sending, onSend: send, onCancel: onCancel)
            }
        }
        .animation(.smooth(duration: 0.3), value: codeSentAt)
        .onAppear { if email.isEmpty { email = initialEmail } }
    }

    private func send() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailAddressStep.looksValid(address) else {
            problem = .failed
            return
        }
        sending = true
        problem = nil
        Task {
            defer { sending = false }
            do throws(APIError) {
                try await account.startEmailSignIn(address)
                email = address
                codeSentAt = .now
            } catch {
                problem = error.signInProblem
            }
        }
    }
}
