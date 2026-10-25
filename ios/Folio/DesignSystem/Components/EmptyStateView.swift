import SwiftUI

/// Empty state: one large SF Symbol on glass plus one sentence (SPEC §3.8).
struct EmptyStateView: View {
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.inkSecondary)
                .frame(width: 88, height: 88)
                .folioGlass(in: .circle)
                .accessibilityHidden(true)
            Text(message)
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(systemImage: "checkmark.seal", message: "All clear.")
        .background(AuraBackground())
}
