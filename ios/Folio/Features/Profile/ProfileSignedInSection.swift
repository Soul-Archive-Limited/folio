import FolioCrypto
import SwiftUI

/// Signed in (SPEC §6.9): who, sync status and last synced, Sync now, Devices, Recovery key,
/// Link a browser or device, Sign out (keep or remove this iPhone's copy), Delete account.
/// The sheets themselves are presented by `ProfileView` (`AccountRoutes`).
struct ProfileSignedInSection: View {
    let routes: AccountRoutes

    @Environment(AccountModel.self) private var account
    @Environment(SyncEngine.self) private var sync
    @Environment(ToastCenter.self) private var toasts

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
                Button { routes.flow = .continuing } label: {
                    ProfileRowLabel(title: account.status == .locked ? "Unlock your diary" : "Finish setting up sync",
                                    systemImage: "lock.open")
                }
            }
            NavigationLink { DevicesView() } label: {
                ProfileRowLabel(title: "Devices", systemImage: "laptopcomputer.and.iphone")
            }
            if account.status == .ready {
                Button(action: showRecoveryKey) {
                    ProfileRowLabel(title: "Recovery key", systemImage: "key")
                }
                Button { routes.showsLink = true } label: {
                    ProfileRowLabel(title: "Link a browser or device", systemImage: "qrcode.viewfinder")
                }
                .accessibilityIdentifier("linkDevice")
            }
            Button { routes.confirmsSignOut = true } label: {
                ProfileRowLabel(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button { routes.showsDelete = true } label: {
                Label("Delete account", systemImage: "trash")
                    .foregroundStyle(.danger)
                    .folioFont(.body)
                    .frame(minHeight: Spacing.minHitTarget)
            }
        }
        .listRowBackground(ProfileRowBackground())
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
                routes.shownRecoveryKey = AccountRoutes.ShownKey(key: key)
            } catch {}
        }
    }
}
