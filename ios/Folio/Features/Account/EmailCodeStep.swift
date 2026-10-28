import SwiftUI

/// Step two of email sign-in: the 6-digit code, filled from Mail by the keyboard
/// (`.oneTimeCode`), resend after 30 s, errors inline (SPEC §6.1).
struct EmailCodeStep: View {
    let email: String
    let sentAt: Date
    let reauth: Bool
    let onResend: () -> Void
    let onDone: () -> Void
    let onChangeEmail: () -> Void

    @Environment(AccountModel.self) private var account
    @State private var code = ""
    @State private var problem: SignInProblem?
    @State private var verifying = false
    @State private var succeeded = 0
    @FocusState private var focused: Bool

    static let resendDelay: TimeInterval = 30

    var body: some View {
        AccountStepLayout(systemImage: "envelope.badge", title: "Check your email",
                          subtitle: "Enter the 6-digit code we sent to \(email).") {
            VStack(spacing: Spacing.xs) {
                TextField("123456", text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .focused($focused)
                    .frame(minHeight: 64)
                    .folioGlass(in: .rect(cornerRadius: Radius.card))
                    .accessibilityLabel("Six-digit code")
                    .onChange(of: code) { _, new in
                        let digits = String(new.filter(\.isNumber).prefix(6))
                        if digits != new { code = digits }
                        if digits.count == 6 { verify() }
                    }
                if let problem {
                    Text(problem.message)
                        .folioFont(.caption)
                        .foregroundStyle(.danger)
                        .multilineTextAlignment(.center)
                }
            }
        } actions: {
            Button(action: verify) {
                Group {
                    if verifying { ProgressView() } else { Text(reauth ? "Confirm" : "Sign in") }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.emberStrong)
            .disabled(code.count != 6 || verifying)
            TimelineView(.periodic(from: sentAt, by: 1)) { context in
                let wait = Int((Self.resendDelay - context.date.timeIntervalSince(sentAt)).rounded(.up))
                Button(wait > 0 ? "Send a new code in \(wait) s" : "Send a new code", action: resend)
                    .disabled(wait > 0)
                    .foregroundStyle(wait > 0 ? .inkTertiary : .emberText)
                    .monospacedDigit()
            }
            .frame(minHeight: Spacing.minHitTarget)
            Button("Use a different email", action: onChangeEmail)
                .foregroundStyle(.inkSecondary)
                .frame(minHeight: Spacing.minHitTarget)
        }
        .folioHaptic(.success, trigger: succeeded)
        .onAppear { focused = true }
    }

    private func resend() {
        code = ""
        problem = nil
        onResend()
    }

    private func verify() {
        guard code.count == 6, !verifying else { return }
        verifying = true
        problem = nil
        Task {
            defer { verifying = false }
            do throws(APIError) {
                try await account.verifyEmailCode(code, email: email, reauth: reauth)
                succeeded += 1
                onDone()
            } catch {
                problem = error.signInProblem
                code = ""
            }
        }
    }
}
