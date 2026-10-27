import SwiftUI

/// Step 4 (SPEC §6.1): "What should we call you?" Optional; used by the greeting.
struct OnboardingNameStep: View {
    @Binding var name: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            AppMark()
                .accessibilityHidden(true)
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
            .padding(.horizontal, Spacing.xxl)
            TextField("Your name", text: $name)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit(onContinue)
                .folioFont(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.l)
                .frame(minHeight: 52)
                .folioGlass(in: .capsule, interactive: true)
                // The whole capsule focuses the field, not just its line of text.
                .contentShape(.capsule)
                .onTapGesture { focused = true }
                .padding(.horizontal, Spacing.xxl)
            Spacer()
            VStack(spacing: Spacing.s) {
                Button(action: onContinue) {
                    Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.ember)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Skip", action: onSkip)
                    .foregroundStyle(.inkSecondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, OnboardingPageDots.clearance)
        }
    }
}
