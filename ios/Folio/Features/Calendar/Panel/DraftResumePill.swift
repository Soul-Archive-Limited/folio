import SwiftUI

/// "Continue your draft" (Batch I): after Folio was fully closed with unsaved writing, a small
/// pill floats above the "+" on the calendar. Tap to pick up where you left off; swipe it
/// away to discard the draft. (Opening "+" still offers the draft too.)
struct DraftResumePill: View {
    let draft: ComposerDraft
    let onResume: () -> Void
    let onDiscard: () -> Void

    @State private var dragX: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.ember)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Continue your draft")
                        .folioFont(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.ink)
                    if !preview.isEmpty {
                        Text(preview).folioFont(.caption).foregroundStyle(.inkSecondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 48)
            .folioGlass(in: .capsule, interactive: true)
        }
        .buttonStyle(.plain)
        .offset(x: dragX)
        .opacity(1 - min(abs(dragX) / 220, 0.8))
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { dragX = $0.translation.width }
                .onEnded { value in
                    if abs(value.predictedEndTranslation.width) > 140 {
                        withAnimation(FolioMotion.standard(reduceMotion: reduceMotion)) { dragX = value.translation.width > 0 ? 400 : -400 }
                        onDiscard()
                    } else {
                        withAnimation(FolioMotion.interactive(reduceMotion: reduceMotion)) { dragX = 0 }
                    }
                }
        )
        .accessibilityLabel("Continue your draft")
        .accessibilityValue(preview)
        .accessibilityHint("Swipe left or right to discard it")
        .accessibilityAction(named: "Discard draft", onDiscard)
    }

    private var preview: String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return MarkdownCodec.document(from: draft.bodyMarkdown).plainText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }
}
