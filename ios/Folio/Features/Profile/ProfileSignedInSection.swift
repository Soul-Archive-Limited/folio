import FolioCrypto
import SwiftUI

/// Signed in (SPEC §6.9): who, sync status and last synced, Sync now, Devices, Recovery key,
/// Link a browser or device, Sign out (keep or remove this iPhone's copy), Delete account.
struct ProfileSignedInSection: View {
    let onContinueSetup: () -> Void

    @Environment(AccountModel.self) private var account
    @Environment(SyncEngine.self) private var sync
    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @State private var showsDevices = false
    @State private var shownRecoveryKey: ShownKey?
    @State private var showsLink = false
    @State private var confirmsSignOut = false
    @State private var showsDelete = false

    struct ShownKey: Identifiable {
        let id = UUID()
        let key: RecoveryKey
    }

    var body: some View {
        Section("Account") {
            ProfileRowLabel(title: LocalizedStringKey(account.session?.email ?? String(localized: "Signed in")),
                            systemImage: providerSymbol)
            if account.status == .ready {
                SyncStatusRow()
                Button { Task { await sync.syncNow() } } label: {
                    ProfileRowLabel(title: "Sync now", systemImage: "arrow.clockwise")
                }
                .disabled(sync.status == .syncing)
                .accessibilityIdentifier("syncNow")
            } else {
                Button(action: onContinueSetup) {
                    ProfileRowLabel(title: account.status == .locked ? "Unlock your diary" : "Finish setting up sync",
                                    systemImage: "lock.open")
                }
            }
            Button { showsDevices = true } label: {
                ProfileRowLabel(title: "Devices", systemImage: "laptopcomputer.and.iphone")
            }
            if account.status == .ready {
                Button(action: showRecoveryKey) {
                    ProfileRowLabel(title: "Recovery key", systemImage: "key")
                }
                Button { showsLink = true } label: {
                    ProfileRowLabel(title: "Link a browser or device", systemImage: "qrcode.viewfinder")
                }
                .accessibilityIdentifier("linkDevice")
            }
            Button { confirmsSignOut = true } label: {
                ProfileRowLabel(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button { showsDelete = true } label: {
                Label("Delete account", systemImage: "trash")
                    .foregroundStyle(.danger)
                    .folioFont(.body)
                    .frame(minHeight: Spacing.minHitTarget)
            }
        }
        .listRowBackground(ProfileRowBackground())
        .navigationDestination(isPresented: $showsDevices) { DevicesView() }
        .sheet(item: $shownRecoveryKey) { shown in
            RecoveryKeyView(key: shown.key, confirming: false)
                .background { AuraBackground() }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsLink) { LinkDeviceView() }
        .sheet(isPresented: $showsDelete) { DeleteAccountView() }
        .confirmationDialog("Sign out of Folio on this iPhone?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Sign out and keep my diary here") { signOut(keep: true) }
            Button("Sign out and remove it from this iPhone", role: .destructive) { signOut(keep: false) }
        } message: {
            Text("Your diary stays in your account either way.")
        }
    }

    private var providerSymbol: String {
        let providers = account.session?.providers ?? []
        if providers.contains("apple") { return "apple.logo" }
        if providers.contains("google") { return "g.circle" }
        return "envelope"
    }

    private func showRecoveryKey() {
        guard let key = account.storedRecoveryKey else {
            toasts.show(ToastMessage(text: "This device doesn't have the recovery key. Open Folio where you created it.", systemImage: "key"))
            return
        }
        Task {
            do throws(LinkApprovalError) {
                try await account.authenticateOwner(reason: String(localized: "Show your recovery key"))
                shownRecoveryKey = ShownKey(key: key)
            } catch {}
        }
    }

    private func signOut(keep: Bool) {
        Task {
            await account.signOut(keepLocalData: keep, store: store)
            toasts.show(ToastMessage(text: keep ? "Signed out. Your diary is still on this iPhone." : "Signed out and removed from this iPhone.",
                                     systemImage: "rectangle.portrait.and.arrow.right"))
        }
    }
}
