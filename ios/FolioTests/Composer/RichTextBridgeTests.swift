import SwiftUI
import Testing
@testable import Folio

/// The editor's attributed text must round-trip to the same document the Markdown fixtures
/// define (SPEC §5.1), so nothing is lost between writing and storage.
@MainActor
@Suite("Rich text bridge")
struct RichTextBridgeTests {
    let context = EnvironmentValues().fontResolutionContext

    @Test("Every canonical fixture survives editor round trips", arguments: MarkdownCodecTests.fixtures.canonical)
    func fixtureRoundTrip(_ fixture: MarkdownCodecTests.Fixtures.Case) {
        // In the editor, a line that starts "1. " *is* a numbered list (typing it starts one),
        // so a stored paragraph with that literal text becomes a list once edited on iOS.
        // Documented in DECISIONS.md; the codec itself keeps the distinction.
        guard fixture.name != "paragraph that looks like a number" else { return }
        // Empty paragraphs at the end are the cursor's resting place, not content.
        var expected = fixture.document
        while let last = expected.blocks.last, last.kind == .paragraph, last.runs.isEmpty { expected.blocks.removeLast() }
        for font in WritingFont.allCases {
            let text = RichTextBridge.attributedString(from: fixture.document, writingFont: font)
            #expect(RichTextBridge.document(from: text, context: context, writingFont: font) == expected, "\(font)")
        }
    }

    @Test("Bold and italic are read back from fonts")
    func inlineStyles() {
        let document = RichDocument(blocks: [.init(.paragraph, runs: [.init("a", [.bold]), .init("b", [.italic]), .init("c", [.bold, .italic])])])
        let text = RichTextBridge.attributedString(from: document)
        #expect(RichTextBridge.document(from: text, context: context) == document)
    }

    @Test("Toggling bold on a selection and back")
    func toggleBold() {
        var text = AttributedString("Hello world")
        let range = text.range(of: "world")!
        var selection = AttributedTextSelection(range: range)
        RichTextEditing.toggle(.bold, in: &text, selection: &selection, context: context, writingFont: .newYork)
        #expect(RichTextBridge.markdown(from: text, context: context) == "Hello **world**")
        RichTextEditing.toggle(.bold, in: &text, selection: &selection, context: context, writingFont: .newYork)
        #expect(RichTextBridge.markdown(from: text, context: context) == "Hello world")
    }

    @Test("Highlight, underline and strikethrough toggle on the selection", arguments: [
        (RichTextEditing.Inline.highlight, "a ==b=="), (.underline, "a <u>b</u>"), (.strikethrough, "a ~~b~~"),
    ])
    func toggleInline(style: RichTextEditing.Inline, expected: String) {
        var text = AttributedString("a b")
        var selection = AttributedTextSelection(range: text.range(of: "b")!)
        RichTextEditing.toggle(style, in: &text, selection: &selection, context: context, writingFont: .newYork)
        #expect(RichTextBridge.markdown(from: text, context: context) == expected)
    }

    @Test("Block styles toggle on the cursor's line and off again")
    func toggleBlocks() {
        for (block, markdown) in [(RichTextEditing.Block.bullet, "- milk"), (.numbered, "1. milk"), (.checklist, "- [ ] milk"),
                                  (.quote, "> milk"), (.heading, "# milk")] {
            var text = AttributedString("milk")
            var selection = AttributedTextSelection(insertionPoint: text.endIndex)
            RichTextEditing.toggle(block, in: &text, selection: &selection, context: context, writingFont: .newYork)
            #expect(RichTextBridge.markdown(from: text, context: context) == markdown)
            RichTextEditing.toggle(block, in: &text, selection: &selection, context: context, writingFont: .newYork)
            #expect(RichTextBridge.markdown(from: text, context: context) == "milk")
        }
    }

    @Test("Ticking a checklist line")
    func tick() {
        var text = RichTextBridge.attributedString(fromMarkdown: "- [ ] post letter")
        var selection = AttributedTextSelection(insertionPoint: text.endIndex)
        RichTextEditing.toggleChecked(in: &text, selection: &selection, context: context, writingFont: .newYork)
        #expect(RichTextBridge.markdown(from: text, context: context) == "- [x] post letter")
    }

    @Test("Return continues a list, and Return on an empty item ends it")
    func continueList() {
        let old = RichTextBridge.attributedString(fromMarkdown: "- milk")
        let new = old + AttributedString("\n")
        let continued = RichTextEditing.continuingList(old: old, new: new, writingFont: .newYork, context: context)
        #expect(continued.map { String($0.characters) } == "• milk\n• ")

        let emptyItem = RichTextBridge.attributedString(fromMarkdown: "- milk\n- ")
        let ended = RichTextEditing.continuingList(old: emptyItem, new: emptyItem + AttributedString("\n"),
                                                   writingFont: .newYork, context: context)
        #expect(ended.map { RichTextBridge.markdown(from: $0, context: context) } == "- milk")
    }

    @Test("Plain typing doesn't trigger list continuation")
    func plainTyping() {
        let old = AttributedString("Hello")
        #expect(RichTextEditing.continuingList(old: old, new: old + AttributedString("\n"), writingFont: .newYork, context: context) == nil)
    }
}
