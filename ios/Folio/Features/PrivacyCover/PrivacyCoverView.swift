import SwiftUI

/// Covers the app whenever it isn't active, so diary content never shows in the app
/// switcher (SPEC §4.3).
struct PrivacyCoverView: View {
    let name: String
    @AppStorage(PrivacyCoverLines.key) private var lineIndex = 0

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

    private var line: String { PrivacyCoverLines.line(lineIndex, name: name) }
}

#Preview("Named") {
    PrivacyCoverView(name: "Sam")
}

#Preview("No name, dark") {
    PrivacyCoverView(name: "").preferredColorScheme(.dark)
}
