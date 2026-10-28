import SwiftUI

/// Step one of email sign-in: the address.
struct EmailAddressStep: View {
    @Binding var email: String
    let problem: SignInProblem?
    let sending: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        AccountStepLayout(systemImage: "envelope", title: "Continue with email",
                          subtitle: "We'll email you a 6-digit code. No password needed.") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .focused($focused)
                    .folioFont(.body)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: 50)
                    .folioGlass(in: .capsule)
                    .accessibilityLabel("Email address")
                if let problem {
                    Text(problem == .failed && !Self.looksValid(email) ? "Enter a full email address." : problem.message)
                        .folioFont(.caption)
                        .foregroundStyle(.danger)
                        .padding(.horizontal, Spacing.m)
                }
            }
        } actions: {
            Button(action: onSend) {
                Group {
                    if sending { ProgressView() } else { Text("Send code") }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.emberStrong)
            .disabled(sending || email.isEmpty)
            Button("Cancel", action: onCancel)
                .foregroundStyle(.emberText)
                .frame(minHeight: Spacing.minHitTarget)
        }
        .onAppear { focused = true }
    }

    /// A light check before asking the server; the server validates properly.
    static func looksValid(_ text: String) -> Bool {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !parts[0].isEmpty && text.count <= 254
    }
}
