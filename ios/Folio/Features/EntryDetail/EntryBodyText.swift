import SwiftUI

/// The rendered entry body: the same styles as the editor, at a 1.45 line height (SPEC §6.5).
struct EntryBodyText: View {
    let markdown: String
    let writingFont: WritingFont

    @ScaledMetric(relativeTo: .body) private var lineSpacing = 17 * 0.45

    var body: some View {
        Text(RichTextBridge.attributedString(fromMarkdown: markdown, writingFont: writingFont))
            .font(RichTextBridge.baseFont(writingFont))
            .foregroundStyle(.ink)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}
