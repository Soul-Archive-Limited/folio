import SwiftUI

/// Step 1: "Your days, kept." — a month assembles tile by tile; one sentence; Get started.
struct OnboardingWelcomeStep: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            AssemblingMonthArt(isActive: true)
                .frame(maxWidth: 300)
                .accessibilityHidden(true)
            OnboardingHeading(title: "Your days, kept.", subtitle: "A private diary built around your calendar. Encrypted, so only you can read it.")
            Spacer()
            OnboardingPrimaryButton(title: "Get started", action: onStart)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
