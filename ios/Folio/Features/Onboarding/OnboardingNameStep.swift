import SwiftUI

/// Step 4 (SPEC §6.1): "What should we call you?" Optional; used by the greeting.
/// Focus belongs to `OnboardingView`, which drops the keyboard on Continue, Skip, any page
/// change and a tap outside the field, so it never follows onto the next page.
struct OnboardingNameStep: View {
    @Binding var name: String
    var focused: FocusState<Bool>.Binding
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            AppMark()
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            VStack(spacing: Spacing.s) {
                Text("What should we call you?")
                    .folioFont(.title1)
                    .foregroundStyle(.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Only used to greet you. It stays on your iPhone.")
                    .folioFont(.callout)
                    .foregroundStyle(.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            // Taps on the words count as "outside" too.
            .allowsHitTesting(false)
            .padding(.horizontal, Spacing.xxl)
            TextField("Your name", text: $name)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused(focused)
                .accessibilityIdentifier("onboarding.name")
                .onSubmit(onContinue)
                .folioFont(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.l)
                .frame(minHeight: 52)
                .folioGlass(in: .capsule, interactive: true)
                // The whole capsule focuses the field, not just its line of text.
                .contentShape(.capsule)
                .onTapGesture { focused.wrappedValue = true }
                .padding(.horizontal, Spacing.xxl)
            Spacer()
            VStack(spacing: Spacing.s) {
                Button(action: onContinue) {
                    Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.emberStrong)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Skip", action: onSkip)
                    .foregroundStyle(.inkSecondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, OnboardingPageDots.clearance)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A tap anywhere outside the field puts the keyboard away. It lives on a layer behind
        // the page, so taps on the field and buttons never reach it.
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { focused.wrappedValue = false }
        }
    }
}
