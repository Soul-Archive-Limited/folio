import SwiftUI

/// Unlock with the recovery key (SPEC §10.4 fallback). Accepts it with or without hyphens,
/// in any case, and reads O as 0 and I/L as 1.
struct RecoveryKeyEntryView: View {
    let onBack: () -> Void

    @Environment(AccountModel.self) private var account
    @State private var text = ""
    @State private var problem: UnlockError?
    @State private var working = false
    @FocusState private var focused: Bool

    var body: some View {
        AccountStepLayout(systemImage: "key", title: "Enter recovery key",
                          subtitle: "The 26-character key you saved when you set up sync.") {
            VStack(spacing: Spacing.xs) {
                TextField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XX", text: $text, axis: .vertical)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding(Spacing.m)
                    .folioGlass(in: .rect(cornerRadius: Radius.card))
                    .accessibilityLabel("Recovery key")
                    .accessibilityIdentifier("recoveryEntry")
                if let problem {
                    Text(message(problem))
                        .folioFont(.caption)
                        .foregroundStyle(.danger)
                        .multilineTextAlignment(.center)
                }
            }
        } actions: {
            Button(action: unlock) {
                Group {
                    if working { ProgressView() } else { Text("Unlock") }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.emberStrong)
            .disabled(text.isEmpty || working)
            Button("Back", action: onBack)
                .foregroundStyle(.emberText)
                .frame(minHeight: Spacing.minHitTarget)
        }
        .onAppear { focused = true }
    }

    private func unlock() {
        working = true
        problem = nil
        Task {
            defer { working = false }
            do throws(UnlockError) {
                try await account.unlock(recoveryKeyText: text)
            } catch {
                problem = error
            }
        }
    }

    private func message(_ error: UnlockError) -> LocalizedStringResource {
        switch error {
        case .malformed: "A recovery key has 26 letters and numbers. Check for a missing character."
        case .wrongKey: "That key doesn't unlock this account's diary."
        case .noEnvelope: "This account has no recovery key yet. Unlock from your other device."
        case .network: "You're offline. Check your connection and try again."
        }
    }
}
