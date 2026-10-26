import SwiftUI

/// The rich body editor (SPEC §5.1): iOS 26 `TextEditor` over an `AttributedString`,
/// limited to Folio's styles. Lists continue on Return.
struct ComposerBodyEditor: View {
    @Bindable var model: ComposerModel
    let placeholder: LocalizedStringKey

    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        TextEditor(text: $model.body, selection: $model.selection)
            .attributedTextFormattingDefinition(FolioFormattingDefinition())
            .font(RichTextBridge.baseFont(model.writingFont))
            .lineSpacing(6)
            .scrollContentBackground(.hidden)
            .overlay(alignment: .topLeading) {
                if model.body.characters.isEmpty {
                    Text(placeholder)
                        .font(RichTextBridge.baseFont(model.writingFont))
                        .foregroundStyle(.inkTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Entry text")
            .onChange(of: model.body) { old, new in
                continueList(old: old, new: new)
            }
    }

    private func continueList(old: AttributedString, new: AttributedString) {
        guard let continued = RichTextEditing.continuingList(old: old, new: new, writingFont: model.writingFont,
                                                             context: fontContext) else { return }
        let lines = RichTextBridge.lines(of: new)
        let cursorLine = RichTextEditing.affectedLineIndices(in: new, selection: model.selection).first ?? lines.count - 1
        model.body = continued
        let newLines = RichTextBridge.lines(of: continued)
        let target = min(cursorLine, newLines.count - 1)
        model.selection = AttributedTextSelection(insertionPoint: newLines[max(target, 0)].upperBound)
    }
}
