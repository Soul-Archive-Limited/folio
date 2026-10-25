import SwiftUI

/// Covers the app whenever it isn't active, so diary content never shows in the app
/// switcher (SPEC §4.3).
struct PrivacyCoverView: View {
    let name: String

    var body: some View {
        ZStack {
            AuraBackground(isFrozen: true)
            VStack(spacing: Spacing.l) {
                AppMark()
                Text(line)
                    .folioFont(.title2)
                    .foregroundStyle(.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.sideMargin)
        }
        .accessibilityElement(children: .combine)
    }

    private var line: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Your pages are safe.") : String(localized: "See you soon, \(trimmed).")
    }
}

#Preview("Named") {
    PrivacyCoverView(name: "Sam")
}

#Preview("No name, dark") {
    PrivacyCoverView(name: "").preferredColorScheme(.dark)
}
