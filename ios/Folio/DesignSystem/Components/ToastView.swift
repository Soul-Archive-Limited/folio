import SwiftUI

struct ToastView: View {
    let message: ToastMessage
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: message.systemImage)
                .foregroundStyle(.ember)
                .accessibilityHidden(true)
            Text(message.text)
                .folioFont(.callout)
                .foregroundStyle(.ink)
            if let undo = message.undo {
                Button(String(localized: undo.title), action: onUndo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ember)
                    .frame(minHeight: Spacing.minHitTarget)
            }
        }
        .padding(.horizontal, Spacing.l)
        .frame(minHeight: 52)
        .folioGlass(in: .capsule)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VStack(spacing: Spacing.m) {
        ToastView(message: ToastMessage(text: "Entry saved"), onUndo: {})
        ToastView(message: ToastMessage(text: "Entry deleted", systemImage: "trash", undo: ToastUndo {}), onUndo: {})
    }
    .padding()
    .background(AuraBackground())
}
