import SwiftUI

/// A circular glass icon button with a 44 pt minimum hit area. The title is read by
/// VoiceOver even though only the icon is shown.
struct GlassIconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        if prominent {
            button.buttonStyle(.glassProminent).tint(.ember)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var button: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .frame(minWidth: Spacing.minHitTarget, minHeight: Spacing.minHitTarget)
            .buttonBorderShape(.circle)
    }
}

#Preview {
    HStack {
        GlassIconButton(title: "Filter", systemImage: "line.3.horizontal.decrease") {}
        GlassIconButton(title: "New entry", systemImage: "plus", prominent: true) {}
    }
    .padding()
    .background(AuraBackground())
}
