import SwiftUI

/// The shared layout of every account step: a glass icon, a title and a line of help, the
/// step's content, and its buttons at the bottom. Scrolls when Dynamic Type makes it tall.
struct AccountStepLayout<Content: View, Actions: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.ember)
                    .frame(width: 88, height: 88)
                    .folioGlass(in: .circle)
                    .accessibilityHidden(true)
                    .padding(.top, Spacing.xxl)
                VStack(spacing: Spacing.xs) {
                    Text(title)
                        .folioFont(.title1)
                        .foregroundStyle(.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .folioFont(.callout)
                        .foregroundStyle(.inkSecondary)
                }
                .multilineTextAlignment(.center)
                content
            }
            .padding(.horizontal, Spacing.xl)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.xs) { actions }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.m)
                .frame(maxWidth: 520)
        }
    }
}
