import SwiftUI

/// Everything after "Continue with …" (SPEC §6.1 steps 5–7): the email steps when chosen,
/// then the recovery key (new account) or unlock (existing account, new device), then the
/// first sync with progress. Shown full screen from onboarding and Profile.
struct AccountFlowView: View {
    /// Start at the email steps (the person tapped "Continue with email").
    var startsWithEmail = false
    let onFinish: () -> Void

    @Environment(AccountModel.self) private var account
    @Environment(SyncEngine.self) private var sync
    @State private var toasts = ToastCenter()

    var body: some View {
        ZStack {
            AuraBackground()
            step
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(account.status)
        }
        .animation(.smooth(duration: 0.35), value: account.status)
        .environment(toasts)
        .toastHost(toasts)
    }

    @ViewBuilder private var step: some View {
        switch account.status {
        case .guest:
            EmailSignInFlow(onDone: {}, onCancel: onFinish)
        case .settingUp:
            if let key = account.pendingRecoveryKey {
                RecoveryKeyView(key: key) {
                    do throws(APIError) {
                        try await account.confirmRecoveryKeySaved()
                    } catch {
                        toasts.show(ToastMessage(text: error.signInProblem.message, systemImage: "exclamationmark.triangle.fill"))
                    }
                }
            }
        case .locked:
            UnlockView(onCancel: onFinish)
        case .ready:
            SyncProgressStep(onDone: onFinish)
        }
    }
}
