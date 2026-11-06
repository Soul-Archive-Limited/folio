import SwiftUI

/// Search text with the matched words marked (Batch J): an accent wash and semibold weight,
/// so the match never relies on colour alone.
enum SearchHighlight {
    static func attributed(_ text: String, terms: [String]) -> AttributedString {
        var result = AttributedString()
        var cursor = text.startIndex
        for range in SearchText.matchRanges(of: terms, in: text) {
            result += AttributedString(text[cursor..<range.lowerBound])
            var match = AttributedString(text[range])
            match.backgroundColor = Color.accent.opacity(0.26)
            match.inlinePresentationIntent = .stronglyEmphasized
            result += match
            cursor = range.upperBound
        }
        result += AttributedString(text[cursor...])
        return result
    }

    /// A one-paragraph window around the first match, so the match is on screen in two lines.
    static func snippet(_ text: String, terms: [String], lead: Int = 36) -> String {
        let flat = text.replacing("\n", with: " ").trimmingCharacters(in: .whitespaces)
        guard let first = SearchText.matchRanges(of: terms, in: flat).first else { return flat }
        let offset = flat.distance(from: flat.startIndex, to: first.lowerBound)
        guard offset > lead else { return flat }
        var start = flat.index(first.lowerBound, offsetBy: -lead)
        // Start on a word, not half-way through one.
        if let space = flat[start..<first.lowerBound].firstIndex(of: " ") { start = flat.index(after: space) }
        return "…" + flat[start...]
    }
}
