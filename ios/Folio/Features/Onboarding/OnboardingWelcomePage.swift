import SwiftUI

/// One of the three welcome pages (SPEC §6.1). The art drifts slower than the page as it
/// scrolls (parallax tied to the scroll position); under Reduce Motion it moves with the page.
struct OnboardingWelcomePage: View {
    let page: OnboardingPage
    let isCurrent: Bool
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: Spacing.xxl)
            art
                .frame(height: 300)
                // Parallax: the art lags the page by about half as it scrolls in or out.
                .scrollTransition(axis: .horizontal) { [reduceMotion] content, phase in
                    content
                        .offset(x: reduceMotion ? 0 : phase.value * 160)
                        .opacity(1 - abs(phase.value) * 0.6)
                }
                .accessibilityHidden(true)
            VStack(spacing: Spacing.s) {
                Text(title)
                    .folioFont(.title1)
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .folioFont(.body)
                    .foregroundStyle(.inkSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xxl)
            .scrollTransition(axis: .horizontal) { [reduceMotion] content, phase in
                content.offset(x: reduceMotion ? 0 : phase.value * 50)
            }
            Spacer()
            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.emberStrong)
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, OnboardingPageDots.clearance)
        }
    }

    @ViewBuilder private var art: some View {
        switch page {
        case .kept: AssemblingMonthArt(isActive: isCurrent)
        case .anyDay: FlippingDateArt(isActive: isCurrent)
        default: PrivacyLockArt(isActive: isCurrent)
        }
    }

    private var title: LocalizedStringKey {
        switch page {
        case .kept: "Your days, kept."
        case .anyDay: "Write for any day."
        default: "Private by design."
        }
    }

    private var message: LocalizedStringKey {
        switch page {
        case .kept: "A diary built around a calendar. Every page lives on its day."
        case .anyDay: "Move your old diaries in. Any date back to 1900."
        default: "Encrypted on your iPhone before it syncs. Not even we can read it."
        }
    }
}
