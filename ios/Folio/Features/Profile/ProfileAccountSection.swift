import SwiftUI

/// Profile → Account (SPEC §6.9). A guest sees "Sync & web access" with the sign-in buttons;
/// a signed-in person sees the account, sync status and the account actions.
struct ProfileAccountSection: View {
    @Environment(AccountModel.self) private var account
    @State private var flow: FlowStart?

    enum FlowStart: Identifiable {
        case email, continuing
        var id: Self { self }
    }

    var body: some View {
        Group {
            if account.isSignedIn {
                ProfileSignedInSection(onContinueSetup: { flow = .continuing })
            } else {
                guestSection
            }
        }
        .fullScreenCover(item: $flow) { start in
            AccountFlowView(startsWithEmail: start == .email) { flow = nil }
        }
    }

    private var guestSection: some View {
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
                SyncSignInButtons(onEmail: { flow = .email }, onDone: { flow = .continuing })
                LegalFooter()
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.xs)
        }
        .listRowBackground(ProfileRowBackground())
    }
}
