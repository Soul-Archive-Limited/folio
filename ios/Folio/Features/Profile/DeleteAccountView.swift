import SwiftUI

/// Delete account (SPEC §10.6, App Store 5.1.1(v)): explain → sign in again → type DELETE →
/// choose whether this iPhone keeps a copy → delete.
struct DeleteAccountView: View {
    @Environment(AccountModel.self) private var account
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .explain
    @State private var typed = ""
    @State private var problem: SignInProblem?
    @State private var working = false
    @State private var toasts = ToastCenter()

    enum Step { case explain, reauth, email, confirm }

    var body: some View {
        ZStack {
            AuraBackground()
            content.transition(.opacity).id(step)
        }
        .animation(.smooth(duration: 0.3), value: step)
        .environment(toasts)
        .toastHost(toasts)
        .interactiveDismissDisabled(working)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .explain:
            AccountStepLayout(systemImage: "trash", title: "Delete your account?",
                              subtitle: "This permanently deletes your account and every entry, photo and task stored on our servers. This can't be undone.") {
                EmptyView()
            } actions: {
                Button { step = account.reauthIsFresh ? .confirm : .reauth } label: {
                    Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.danger)
                Button("Cancel") { dismiss() }.foregroundStyle(.emberText).frame(minHeight: Spacing.minHitTarget)
            }
        case .reauth:
            AccountStepLayout(systemImage: "person.badge.key", title: "Confirm it's you",
                              subtitle: "Sign in again with the account you use here.") {
                SyncSignInButtons(reauth: true, onEmail: { step = .email }, onDone: { step = .confirm })
            } actions: {
                Button("Cancel") { dismiss() }.foregroundStyle(.emberText).frame(minHeight: Spacing.minHitTarget)
            }
        case .email:
            EmailSignInFlow(reauth: true, initialEmail: account.session?.email ?? "",
                            onDone: { step = .confirm }, onCancel: { step = .reauth })
        case .confirm:
            confirmStep
        }
    }

    private var confirmStep: some View {
        AccountStepLayout(systemImage: "exclamationmark.triangle", title: "Type DELETE to confirm",
                          subtitle: "Your account, its devices and everything stored on our servers will be deleted.") {
            VStack(spacing: Spacing.xs) {
                TextField("DELETE", text: $typed)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .frame(width: 200, height: 50)
                    .folioGlass(in: .capsule)
                    .accessibilityIdentifier("deleteConfirm")
                if let problem {
                    Text(problem.message).folioFont(.caption).foregroundStyle(.danger).multilineTextAlignment(.center)
                }
            }
        } actions: {
            Button { delete(keep: true) } label: {
                Text("Delete account, keep my diary on this iPhone").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.danger)
            .disabled(typed != "DELETE" || working)
            .accessibilityIdentifier("deleteKeep")
            Button { delete(keep: false) } label: {
                Text("Delete account and erase this iPhone too").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.danger)
            .disabled(typed != "DELETE" || working)
            Button("Cancel") { dismiss() }.foregroundStyle(.emberText).frame(minHeight: Spacing.minHitTarget)
        }
        .overlay { if working { ProgressView().controlSize(.large) } }
    }

    private func delete(keep: Bool) {
        working = true
        problem = nil
        Task {
            defer { working = false }
            do throws(APIError) {
                try await account.deleteAccount(keepLocalData: keep, store: store)
                dismiss()
            } catch .server(403, "reauth_required") {
                step = .reauth
            } catch {
                problem = error.signInProblem
            }
        }
    }
}
