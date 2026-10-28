import SwiftUI

/// Step 5 (SPEC §6.1): keep the diary in sync, or stay a guest on this iPhone. Signing in
/// opens the rest of the account steps (recovery key or unlock, first sync) full screen;
/// onboarding finishes when they do.
struct OnboardingSyncStep: View {
    let onGuest: () -> Void

    @Environment(AccountModel.self) private var account
    @State private var flow: FlowStart?

    enum FlowStart: Identifiable {
        case email, afterProvider
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.ember)
                .frame(width: 112, height: 112)
                .folioGlass(in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.s) {
                Text("Keep your diary in sync?")
                    .folioFont(.title1)
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Use Folio on the web and on a new iPhone. Encrypted end to end.")
                    .folioFont(.callout)
                    .foregroundStyle(.inkSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xxl)
            Spacer()
            VStack(spacing: Spacing.m) {
                SyncSignInButtons(onEmail: { flow = .email }, onDone: { flow = .afterProvider })
                Button("Not now — keep it on this iPhone", action: onGuest)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.emberText)
                    .frame(minHeight: Spacing.minHitTarget)
                LegalFooter()
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, OnboardingPageDots.clearance)
        }
        .fullScreenCover(item: $flow) { start in
            AccountFlowView(startsWithEmail: start == .email) {
                flow = nil
                // Signed in (even if the key comes later from Profile): onboarding is done.
                if account.isSignedIn { onGuest() }
            }
        }
    }
}
