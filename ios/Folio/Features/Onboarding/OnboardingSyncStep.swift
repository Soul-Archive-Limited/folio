import SwiftUI

/// Step 5 (SPEC §6.1): keep the diary in sync, or stay a guest on this iPhone. Release
/// builds before Phase 10 only offer guest mode, so no dead button ships.
struct OnboardingSyncStep: View {
    let onGuest: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: FeatureFlags.showsSignIn ? "arrow.triangle.2.circlepath.icloud" : "iphone")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.ember)
                .frame(width: 112, height: 112)
                .folioGlass(in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.s) {
                Text(FeatureFlags.showsSignIn ? "Keep your diary in sync?" : "Everything stays on this iPhone.")
                    .folioFont(.title1)
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(FeatureFlags.showsSignIn
                     ? "Use Folio on the web and on a new iPhone. Encrypted end to end."
                     : "No account needed. Your pages stay on this device.")
                    .folioFont(.callout)
                    .foregroundStyle(.inkSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xxl)
            Spacer()
            VStack(spacing: Spacing.m) {
                if FeatureFlags.showsSignIn {
                    SyncSignInButtons()
                    Button("Not now — keep it on this iPhone", action: onGuest)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.emberText)
                        .frame(minHeight: Spacing.minHitTarget)
                    LegalFooter()
                } else {
                    Button(action: onGuest) {
                        Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.emberStrong)
                }
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, OnboardingPageDots.clearance)
        }
    }
}
