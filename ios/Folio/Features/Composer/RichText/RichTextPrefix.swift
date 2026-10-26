import Foundation

/// Block markers as they appear in the editor. SwiftUI's `TextEditor` has no list or quote
/// paragraph styles, so blocks are visible line prefixes: deleting the prefix turns the
/// line back into a paragraph, exactly as a person would expect.
nonisolated enum RichTextPrefix {
    static let bullet = "• "
    static let checklistOpen = "☐ "
    static let checklistDone = "☑ "
    static let quote = "▍ "

    /// The block kind and prefix length a line starts with, or `.paragraph` / 0.
    static func parse(_ line: String) -> (kind: RichDocument.BlockKind, prefixLength: Int) {
        if line.hasPrefix(checklistOpen) { return (.checklist(checked: false), checklistOpen.count) }
        if line.hasPrefix(checklistDone) { return (.checklist(checked: true), checklistDone.count) }
        if line.hasPrefix(bullet) { return (.bullet, bullet.count) }
        if line.hasPrefix(quote) { return (.quote, quote.count) }
        if let dot = line.firstIndex(of: "."), !line[..<dot].isEmpty, line[..<dot].allSatisfy(\.isNumber),
           line[line.index(after: dot)...].hasPrefix(" ") {
            return (.numbered, line.distance(from: line.startIndex, to: dot) + 2)
        }
        return (.paragraph, 0)
    }

    static func prefix(for kind: RichDocument.BlockKind, number: Int) -> String {
        switch kind {
        case .paragraph, .heading: ""
        case .bullet: bullet
        case .numbered: "\(number). "
        case .quote: quote
        case .checklist(let checked): checked ? checklistDone : checklistOpen
        }
    }
}
