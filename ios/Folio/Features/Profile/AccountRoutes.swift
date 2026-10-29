import FolioCrypto
import SwiftUI

/// What Profile → Account is showing. Owned by `ProfileView` and presented there, not inside
/// the List: a sheet attached to a List section doesn't present reliably, and the section
/// itself is replaced when signing in finishes — which would close the flow half-way.
@Observable
final class AccountRoutes {
    enum FlowStart: Identifiable {
        case email, continuing
        var id: Self { self }
    }

    struct ShownKey: Identifiable {
        let id = UUID()
        let key: RecoveryKey
    }

    var flow: FlowStart?
    var shownRecoveryKey: ShownKey?
    var showsLink = false
    var showsDelete = false
    var confirmsSignOut = false
}

/// Presents everything `AccountRoutes` asks for. Attach to the Profile List.
struct AccountPresentations: ViewModifier {
    @Bindable var routes: AccountRoutes

    @Environment(AccountModel.self) private var account
    @Environment(DiaryStore.self) private var store
    @Environment(ToastCenter.self) private var toasts

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $routes.flow) { start in
                AccountFlowView(startsWithEmail: start == .email) { routes.flow = nil }
                    .privacyCovered()
            }
            .sheet(item: $routes.shownRecoveryKey) { shown in
                RecoveryKeyView(key: shown.key, confirming: false)
                    .background { AuraBackground() }
                    .presentationDragIndicator(.visible)
                    .privacyCovered()
            }
            // Every presentation gets its own cover: sheets sit above the root's overlay.
            .sheet(isPresented: $routes.showsLink) { LinkDeviceView().privacyCovered() }
            .sheet(isPresented: $routes.showsDelete) { DeleteAccountView().privacyCovered() }
            .confirmationDialog("Sign out of Folio on this iPhone?", isPresented: $routes.confirmsSignOut, titleVisibility: .visible) {
                Button("Sign out and keep my diary here") { signOut(keep: true) }
                Button("Sign out and remove it from this iPhone", role: .destructive) { signOut(keep: false) }
            } message: {
                Text("Your diary stays in your account either way.")
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
