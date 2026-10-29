import SwiftUI

/// Profile → Account (SPEC §6.9). A guest sees "Sync & web access" with the sign-in buttons;
/// a signed-in person sees the account, sync status and the account actions.
struct ProfileAccountSection: View {
    let routes: AccountRoutes

    @Environment(AccountModel.self) private var account

    var body: some View {
        if account.isSignedIn {
            ProfileSignedInSection(routes: routes)
        } else {
            Section("Account") {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Sync & web access")
                                .folioFont(.headline)
                                .foregroundStyle(.ink)
                            Text("Use Folio on the web and on a new iPhone. Encrypted end to end.")
                                .folioFont(.callout)
                                .foregroundStyle(.inkSecondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            .foregroundStyle(.ember)
                    }
                    SyncSignInButtons(onEmail: { routes.flow = .email }, onDone: { routes.flow = .continuing })
                    LegalFooter()
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, Spacing.xs)
            }
            .listRowBackground(ProfileRowBackground())
        }
    }
}
