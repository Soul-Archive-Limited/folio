import SwiftUI

/// The glass explainer shown before any system permission prompt (SPEC §7). One explainer
/// may cover several prompts in a row (dictation: microphone, then speech recognition).
struct PermissionExplainer: View {
    let systemImage: String
    let message: LocalizedStringKey
    var footnote: LocalizedStringKey?
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.ember)
                .frame(width: 72, height: 72)
                .folioGlass(in: .circle)
                .accessibilityHidden(true)
            Text(message)
                .folioFont(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let footnote {
                Text(footnote)
                    .folioFont(.callout)
                    .foregroundStyle(.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            GlassEffectContainer(spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    Button("Not now") { dismiss() }
                        .buttonStyle(.glass)
                    Button("Continue", action: onContinue)
                        .buttonStyle(.glassProminent)
                        .tint(.emberStrong)
                }
            }
        }
        .padding(Spacing.xl)
        .presentationDetents([.height(footnote == nil ? 300 : 340)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Color.bg.sheet(isPresented: .constant(true)) {
        PermissionExplainer(systemImage: "camera", message: "Folio uses the camera only when you choose to take a photo for an entry.", onContinue: {})
    }
}
