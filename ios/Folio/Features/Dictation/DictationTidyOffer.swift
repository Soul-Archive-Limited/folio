import SwiftUI

/// After dictation, a small offer to tidy punctuation and capitals with Apple's on-device model
/// (Batch I). Only accepted when the words are exactly the ones heard; otherwise nothing changes.
struct DictationTidyOffer: View {
    let text: String
    let model: ComposerModel
    let assistant: WritingAssistant
    let onClose: () -> Void

    @State private var isWorking = false
    @State private var note: LocalizedStringKey?

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "sparkles").foregroundStyle(.ember).accessibilityHidden(true)
            Text(note ?? "Tidy punctuation and capitals?")
                .folioFont(.callout)
                .foregroundStyle(.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isWorking {
                ProgressView()
            } else if note == nil {
                Button("Tidy", action: tidy)
                    .buttonStyle(.glassProminent)
                    .tint(.emberStrong)
            }
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .foregroundStyle(.inkSecondary)
                .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
        }
        .padding(.leading, Spacing.m)
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: 52)
        .folioGlass(in: .capsule)
        .padding(.horizontal, Spacing.sideMargin)
        .padding(.bottom, Spacing.xs)
        .task(id: note) {
            guard note != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            onClose()
        }
    }

    private func tidy() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let tidied = try await assistant.tidyDictation(text).trimmingCharacters(in: .whitespacesAndNewlines)
                if DictationRules.onlyPunctuationChanged(from: text, to: tidied), model.replaceLast(text, with: tidied) {
                    note = "Tidied."
                } else {
                    note = "It already reads well."
                }
            } catch {
                note = "Couldn't tidy it this time."
            }
        }
    }
}
