import SwiftUI

/// Converts between the editor's `AttributedString` and `RichDocument` (SPEC §5.1).
///
/// Inline styles map to real attributes: bold/italic to the font, underline and strikethrough
/// to line styles, highlight to a background colour. Headings are a larger font; lists,
/// checklists and quotes are line prefixes (`RichTextPrefix`). Reading back uses iOS 26's
/// `Font.Resolved` to tell bold and italic apart.
enum RichTextBridge {
    static var highlightColor: Color { Color(.ember).opacity(0.28) }
    static var prefixColor: Color { Color(.inkSecondary) }
    static var quoteColor: Color { Color(.ember) }

    static func baseFont(_ writing: WritingFont) -> Font { writing.font(.body) }
    static func headingFont(_ writing: WritingFont) -> Font { .system(.title2, design: writing.design, weight: .medium) }

    // MARK: Document → editor

    static func attributedString(from document: RichDocument, writingFont: WritingFont = .newYork) -> AttributedString {
        var output = AttributedString()
        var number = 0
        for (index, block) in document.blocks.enumerated() {
            if index > 0 { output += AttributedString("\n") }
            number = block.kind == .numbered ? number + 1 : 0
            let lineFont = block.kind == .heading ? headingFont(writingFont) : baseFont(writingFont)
            let prefix = RichTextPrefix.prefix(for: block.kind, number: number)
            if !prefix.isEmpty {
                var marker = AttributedString(prefix)
                marker.font = lineFont
                marker.foregroundColor = block.kind == .quote ? quoteColor : prefixColor
                output += marker
            }
            for run in block.runs {
                output += styled(run, base: lineFont)
            }
        }
        return output
    }

    static func styled(_ run: RichDocument.Run, base: Font) -> AttributedString {
        var text = AttributedString(run.text)
        var font = base
        if run.styles.contains(.bold) { font = font.bold() }
        if run.styles.contains(.italic) { font = font.italic() }
        text.font = font
        if run.styles.contains(.underline) { text.underlineStyle = .single }
        if run.styles.contains(.strikethrough) { text.strikethroughStyle = .single }
        if run.styles.contains(.highlight) { text.backgroundColor = highlightColor }
        return text
    }

    // MARK: Editor → document

    static func document(from text: AttributedString, context: Font.Context, writingFont: WritingFont = .newYork) -> RichDocument {
        let bodySize = baseFont(writingFont).resolve(in: context).pointSize
        var blocks: [RichDocument.Block] = []
        for line in lines(of: text) {
            let plain = String(text[line].characters)
            var (kind, prefixLength) = RichTextPrefix.parse(plain)
            let contentStart = text.index(line.lowerBound, offsetByCharacters: prefixLength)
            let content = contentStart..<line.upperBound
            var runs: [RichDocument.Run] = []
            var isHeading = false
            for run in text[content].runs {
                let string = String(text[run.range].characters)
                var styles = Set<RichDocument.InlineStyle>()
                if let font = run.font {
                    let resolved = font.resolve(in: context)
                    if resolved.pointSize > bodySize * 1.15 { isHeading = true }
                    // Headings use a medium weight, so bold inside a heading still reads as bold.
                    if resolved.isBold { styles.insert(.bold) }
                    if resolved.isItalic { styles.insert(.italic) }
                }
                if run.underlineStyle != nil { styles.insert(.underline) }
                if run.strikethroughStyle != nil { styles.insert(.strikethrough) }
                if run.backgroundColor != nil { styles.insert(.highlight) }
                runs.append(RichDocument.Run(string, styles))
            }
            if kind == .paragraph && isHeading { kind = .heading }
            blocks.append(RichDocument.Block(kind, runs: MarkdownCodec.normalized(runs)))
        }
        // A trailing empty line is the cursor's resting place, not content.
        while let last = blocks.last, last.kind == .paragraph, last.runs.isEmpty {
            blocks.removeLast()
        }
        return RichDocument(blocks: blocks)
    }

    /// Ranges of each line, excluding the newline.
    static func lines(of text: AttributedString) -> [Range<AttributedString.Index>] {
        var ranges: [Range<AttributedString.Index>] = []
        var start = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            if text.characters[index] == "\n" {
                ranges.append(start..<index)
                start = text.characters.index(after: index)
            }
            index = text.characters.index(after: index)
        }
        ranges.append(start..<text.endIndex)
        return ranges
    }

    static func markdown(from text: AttributedString, context: Font.Context, writingFont: WritingFont = .newYork) -> String {
        MarkdownCodec.markdown(from: document(from: text, context: context, writingFont: writingFont))
    }

    static func attributedString(fromMarkdown markdown: String, writingFont: WritingFont = .newYork) -> AttributedString {
        attributedString(from: MarkdownCodec.document(from: markdown), writingFont: writingFont)
    }
}
