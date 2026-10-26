import SwiftUI

/// The Aa popover: inline styles on the selection, block styles on the current lines.
struct FormatPopover: View {
    @Bindable var model: ComposerModel
    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GlassEffectContainer(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    inline(.bold, title: "Bold", symbol: "bold")
                    inline(.italic, title: "Italic", symbol: "italic")
                    inline(.underline, title: "Underline", symbol: "underline")
                    inline(.strikethrough, title: "Strikethrough", symbol: "strikethrough")
                    inline(.highlight, title: "Highlight", symbol: "highlighter")
                }
            }
            Divider()
            GlassEffectContainer(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    block(.heading, title: "Heading", symbol: "textformat.size.larger")
                    block(.bullet, title: "Bulleted list", symbol: "list.bullet")
                    block(.numbered, title: "Numbered list", symbol: "list.number")
                    block(.checklist, title: "Checklist", symbol: "checklist")
                    block(.quote, title: "Quote", symbol: "text.quote")
                }
            }
            if case .checklist = currentBlock {
                Button("Tick item", systemImage: "checkmark.circle", action: toggleChecked)
                    .buttonStyle(.glass)
            }
        }
        .padding(Spacing.m)
        .labelStyle(.iconOnly)
    }

    private var currentBlock: RichDocument.BlockKind {
        RichTextEditing.currentBlock(in: model.body, selection: model.selection, context: fontContext,
                                     writingFont: model.writingFont)
    }

    private func inline(_ style: RichTextEditing.Inline, title: LocalizedStringKey, symbol: String) -> some View {
        let isOn = RichTextEditing.isActive(style, in: model.body, selection: model.selection, context: fontContext)
        return Button(title, systemImage: symbol) {
            RichTextEditing.toggle(style, in: &model.body, selection: &model.selection, context: fontContext,
                                   writingFont: model.writingFont)
        }
        .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
        .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
        .background(isOn ? AnyShapeStyle(.ember) : AnyShapeStyle(.clear), in: .circle)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func block(_ style: RichTextEditing.Block, title: LocalizedStringKey, symbol: String) -> some View {
        let target = RichTextEditing.kind(for: style)
        let isOn = switch (currentBlock, target) {
        case (.checklist, .checklist): true
        default: currentBlock == target
        }
        return Button(title, systemImage: symbol) {
            RichTextEditing.toggle(style, in: &model.body, selection: &model.selection, context: fontContext,
                                   writingFont: model.writingFont)
        }
        .frame(width: Spacing.minHitTarget, height: Spacing.minHitTarget)
        .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.ink))
        .background(isOn ? AnyShapeStyle(.ember) : AnyShapeStyle(.clear), in: .circle)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggleChecked() {
        RichTextEditing.toggleChecked(in: &model.body, selection: &model.selection, context: fontContext,
                                      writingFont: model.writingFont)
    }
}
