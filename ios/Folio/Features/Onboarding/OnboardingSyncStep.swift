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
        // Batch O: on an iPhone SE the full layout was taller than the screen, so the title and
        // subtitle were cut and the icon touched the progress bar. A smaller icon first, then a
        // scroll view at the largest text sizes.
        ViewThatFits(in: .vertical) {
            content(icon: 112, spacing: Spacing.xl)
            content(icon: 64, spacing: Spacing.m)
            // iPhone SE: no icon, so "Not now — keep it on this iPhone" (guest mode) stays on screen.
            content(icon: 0, spacing: Spacing.s)
            ScrollView { content(icon: 0, spacing: Spacing.s) }
        }
        .fullScreenCover(item: $flow) { start in
            AccountFlowView(startsWithEmail: start == .email) {
                flow = nil
                // Signed in (even if the key comes later from Profile): onboarding is done.
                if account.isSignedIn { onGuest() }
            }
            .privacyCovered()
        }
    }

    private func content(icon: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            Spacer(minLength: 0)
            if icon > 0 {
                Image("folio.sync")
                    .font(.system(size: icon / 2, weight: .regular))
                    .foregroundStyle(.accent)
                    .frame(width: icon, height: icon)
                    .folioGlass(in: .circle)
                    .accessibilityHidden(true)
            }
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
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.xxl)
            Spacer(minLength: 0)
            VStack(spacing: Spacing.m) {
                SyncSignInButtons(onEmail: { flow = .email }, onDone: { flow = .afterProvider })
                Button("Not now — keep it on this iPhone", action: onGuest)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.accentText)
                    .frame(minHeight: Spacing.minHitTarget)
                LegalFooter()
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.l)
        }
    }
}
