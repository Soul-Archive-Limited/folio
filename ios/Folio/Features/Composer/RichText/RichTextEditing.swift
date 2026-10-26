import SwiftUI

/// The formatting commands behind the Aa popover (SPEC §6.4). Inline styles toggle on the
/// selection; block styles toggle on every line the selection touches.
enum RichTextEditing {
    enum Inline: CaseIterable {
        case bold, italic, underline, strikethrough, highlight
    }

    enum Block: CaseIterable {
        case heading, bullet, numbered, checklist, quote
    }

    // MARK: Inline

    static func isActive(_ style: Inline, in text: AttributedString, selection: AttributedTextSelection, context: Font.Context) -> Bool {
        let attributes = selection.typingAttributes(in: text)
        switch style {
        case .bold: return attributes.font?.resolve(in: context).isBold ?? false
        case .italic: return attributes.font?.resolve(in: context).isItalic ?? false
        case .underline: return attributes.underlineStyle != nil
        case .strikethrough: return attributes.strikethroughStyle != nil
        case .highlight: return attributes.backgroundColor != nil
        }
    }

    static func toggle(_ style: Inline, in text: inout AttributedString, selection: inout AttributedTextSelection,
                       context: Font.Context, writingFont: WritingFont) {
        let turnOn = !isActive(style, in: text, selection: selection, context: context)
        let base = RichTextBridge.baseFont(writingFont)
        text.transformAttributes(in: &selection) { container in
            switch style {
            case .bold: container.font = (container.font ?? base).bold(turnOn)
            case .italic: container.font = (container.font ?? base).italic(turnOn)
            case .underline: container.underlineStyle = turnOn ? .single : nil
            case .strikethrough: container.strikethroughStyle = turnOn ? .single : nil
            case .highlight: container.backgroundColor = turnOn ? RichTextBridge.highlightColor : nil
            }
        }
    }

    // MARK: Block

    /// The block kind of the line holding the cursor.
    static func currentBlock(in text: AttributedString, selection: AttributedTextSelection, context: Font.Context,
                             writingFont: WritingFont) -> RichDocument.BlockKind {
        let lineIndex = affectedLineIndices(in: text, selection: selection).first ?? 0
        let document = RichTextBridge.document(from: text, context: context, writingFont: writingFont)
        return document.blocks.indices.contains(lineIndex) ? document.blocks[lineIndex].kind : .paragraph
    }

    /// Toggles a block style on the selected lines by rebuilding them through `RichDocument`,
    /// which keeps prefixes, numbering and fonts consistent. The cursor is restored to the
    /// same line.
    static func toggle(_ block: Block, in text: inout AttributedString, selection: inout AttributedTextSelection,
                       context: Font.Context, writingFont: WritingFont) {
        let lineIndices = affectedLineIndices(in: text, selection: selection)
        var document = RichTextBridge.document(from: text, context: context, writingFont: writingFont)
        let lineCount = RichTextBridge.lines(of: text).count
        while document.blocks.count < lineCount { document.blocks.append(RichDocument.Block()) }
        let target = kind(for: block)
        let allAlready = lineIndices.allSatisfy { index in
            document.blocks.indices.contains(index) && sameFamily(document.blocks[index].kind, target)
        }
        for index in lineIndices where document.blocks.indices.contains(index) {
            document.blocks[index].kind = allAlready ? .paragraph : target
        }
        text = RichTextBridge.attributedString(from: document, writingFont: writingFont)
        let lines = RichTextBridge.lines(of: text)
        if let last = lineIndices.last, lines.indices.contains(last) {
            selection = AttributedTextSelection(insertionPoint: lines[last].upperBound)
        }
    }

    /// Ticks or unticks a checklist line (there's no tap target inside the editor).
    static func toggleChecked(in text: inout AttributedString, selection: inout AttributedTextSelection,
                              context: Font.Context, writingFont: WritingFont) {
        let lineIndices = affectedLineIndices(in: text, selection: selection)
        var document = RichTextBridge.document(from: text, context: context, writingFont: writingFont)
        for index in lineIndices where document.blocks.indices.contains(index) {
            if case .checklist(let checked) = document.blocks[index].kind {
                document.blocks[index].kind = .checklist(checked: !checked)
            }
        }
        text = RichTextBridge.attributedString(from: document, writingFont: writingFont)
        let lines = RichTextBridge.lines(of: text)
        if let last = lineIndices.last, lines.indices.contains(last) {
            selection = AttributedTextSelection(insertionPoint: lines[last].upperBound)
        }
    }

    /// Continues a list when Return is pressed at the end of a list line, and ends it when
    /// Return is pressed on an empty list line. Returns nil when nothing needs to change.
    static func continuingList(old: AttributedString, new: AttributedString, writingFont: WritingFont,
                               context: Font.Context) -> AttributedString? {
        let oldLines = RichTextBridge.lines(of: old).map { String(old[$0].characters) }
        let newLines = RichTextBridge.lines(of: new).map { String(new[$0].characters) }
        guard newLines.count == oldLines.count + 1 else { return nil }
        // Find the line that was split.
        guard let split = zip(oldLines, newLines).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
                ?? (newLines.count >= 2 ? newLines.count - 2 : nil),
              newLines.indices.contains(split + 1) else { return nil }
        let (kind, prefixLength) = RichTextPrefix.parse(newLines[split])
        guard kind != .paragraph, newLines[split + 1].isEmpty else { return nil }
        var document = RichTextBridge.document(from: new, context: context, writingFont: writingFont)
        while document.blocks.count < newLines.count { document.blocks.append(RichDocument.Block()) }
        if newLines[split].count == prefixLength {
            // Return on an empty list item ends the list.
            document.blocks[split].kind = .paragraph
            document.blocks.remove(at: split + 1)
        } else {
            let nextKind: RichDocument.BlockKind = if case .checklist = kind { .checklist(checked: false) } else { kind }
            document.blocks[split + 1] = RichDocument.Block(nextKind)
        }
        return RichTextBridge.attributedString(from: document, writingFont: writingFont)
    }

    static func kind(for block: Block) -> RichDocument.BlockKind {
        switch block {
        case .heading: .heading
        case .bullet: .bullet
        case .numbered: .numbered
        case .checklist: .checklist(checked: false)
        case .quote: .quote
        }
    }

    private static func sameFamily(_ a: RichDocument.BlockKind, _ b: RichDocument.BlockKind) -> Bool {
        switch (a, b) {
        case (.checklist, .checklist): true
        default: a == b
        }
    }

    /// Indices of the lines the selection or cursor touches.
    static func affectedLineIndices(in text: AttributedString, selection: AttributedTextSelection) -> [Int] {
        let lines = RichTextBridge.lines(of: text)
        let points: [Range<AttributedString.Index>] = switch selection.indices(in: text) {
        case .insertionPoint(let index): [index..<index]
        case .ranges(let ranges): ranges.ranges.map { $0 }
        }
        var result = Set<Int>()
        for range in points {
            for (index, line) in lines.enumerated() where line.lowerBound <= range.upperBound && range.lowerBound <= line.upperBound {
                result.insert(index)
            }
        }
        return result.sorted().isEmpty ? [max(lines.count - 1, 0)] : result.sorted()
    }
}
