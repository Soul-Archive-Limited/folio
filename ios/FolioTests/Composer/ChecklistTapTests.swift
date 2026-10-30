import SwiftUI
import Testing
@testable import Folio

@MainActor
@Suite("Tapping a checklist box ticks it (Batch I)")
struct ChecklistTapTests {
    let context = EnvironmentValues().fontResolutionContext

    private func text(_ markdown: String) -> AttributedString {
        RichTextBridge.attributedString(fromMarkdown: markdown)
    }

    private func caret(_ text: AttributedString, line: Int, offset: Int) -> AttributedTextSelection {
        let start = RichTextBridge.lines(of: text)[line].lowerBound
        return AttributedTextSelection(insertionPoint: text.characters.index(start, offsetBy: offset))
    }

    @Test("A caret on the box or just after it is a tap on the box", arguments: [0, 1])
    func caretOnBox(offset: Int) {
        let body = text("Shopping\n- [ ] Milk\n- [x] Bread")
        #expect(RichTextEditing.checkboxLine(in: body, selection: caret(body, line: 1, offset: offset)) == 1)
    }

    @Test("A caret in the item's words or on a plain line isn't")
    func caretElsewhere() {
        let body = text("Shopping\n- [ ] Milk")
        #expect(RichTextEditing.checkboxLine(in: body, selection: caret(body, line: 1, offset: 4)) == nil)
        #expect(RichTextEditing.checkboxLine(in: body, selection: caret(body, line: 0, offset: 0)) == nil)
    }

    @Test("Toggling ticks, unticks and keeps the words")
    func toggles() {
        var body = text("- [ ] Milk\n- [x] Bread")
        var selection = caret(body, line: 0, offset: 0)
        RichTextEditing.toggleChecked(line: 0, in: &body, selection: &selection, context: context, writingFont: .newYork)
        #expect(RichTextBridge.markdown(from: body, context: context) == "- [x] Milk\n- [x] Bread")
        RichTextEditing.toggleChecked(line: 1, in: &body, selection: &selection, context: context, writingFont: .newYork)
        #expect(RichTextBridge.markdown(from: body, context: context) == "- [x] Milk\n- [ ] Bread")
        #expect(RichTextEditing.checkboxLine(in: body, selection: selection) == nil, "the caret moves off the box")
    }
}
