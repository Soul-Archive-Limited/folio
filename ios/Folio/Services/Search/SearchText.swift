import Foundation

/// Word splitting and folding for on-device search (Batch J). The same rules run on the
/// diary and on the query, so "Café" finds "cafe" and Hindi words stay whole.
///
/// - Letters, digits and combining marks are word characters; everything else separates words.
/// - Case is folded everywhere. Accents are dropped only from Latin letters: in Devanagari and
///   other scripts the combining marks are vowel signs, part of the word.
/// - Chinese and Japanese characters are a word each (no spaces between words there).
/// - `web/src/app/lib/search.ts` does the same; `shared/search-fixtures.json` pins both.
nonisolated enum SearchText {
    /// The folded words of `text`, in order (duplicates kept).
    static func words(in text: String) -> [String] {
        var words: [String] = []
        var current = String.UnicodeScalarView()
        var lastBaseIsLatin = false
        for scalar in text.decomposedStringWithCanonicalMapping.unicodeScalars {
            let properties = scalar.properties
            if properties.generalCategory == .nonspacingMark || properties.generalCategory == .spacingMark
                || properties.generalCategory == .enclosingMark {
                // A mark belongs to the word it follows; Latin accents are folded away.
                if !current.isEmpty && !lastBaseIsLatin { current.append(scalar) }
                continue
            }
            if isIdeographic(scalar.value) {
                if !current.isEmpty { words.append(String(current)) }
                words.append(String(scalar))
                current = String.UnicodeScalarView()
                lastBaseIsLatin = false
            } else if properties.isAlphabetic || properties.numericType != nil {
                lastBaseIsLatin = scalar.value < 0x0250
                current.append(contentsOf: properties.lowercaseMapping.unicodeScalars)
            } else if !current.isEmpty {
                words.append(String(current))
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty { words.append(String(current)) }
        return words
    }

    static func isIdeographic(_ value: UInt32) -> Bool {
        (0x3040...0x30FF).contains(value) || (0x3400...0x4DBF).contains(value) || (0x4E00...0x9FFF).contains(value)
            || (0xF900...0xFAFF).contains(value) || (0x20000...0x2FFFF).contains(value)
    }

    /// Sorted, unique folded words: what a document stores for prefix lookups.
    static func vocabulary(of parts: [String]) -> [String] {
        var set = Set<String>()
        for part in parts { set.formUnion(words(in: part)) }
        return set.sorted()
    }

    /// Whether any word in the sorted `vocabulary` starts with `prefix` (binary search).
    static func vocabulary(_ vocabulary: [String], hasPrefix prefix: String) -> Bool {
        var low = 0
        var high = vocabulary.count
        while low < high {
            let mid = (low + high) / 2
            if vocabulary[mid] < prefix { low = mid + 1 } else { high = mid }
        }
        return low < vocabulary.count && vocabulary[low].hasPrefix(prefix)
    }

    /// Ranges in `text` where a word starts with one of the folded `terms` — for highlighting
    /// the visible rows only.
    static func matchRanges(of terms: [String], in text: String) -> [Range<String.Index>] {
        guard !terms.isEmpty, !text.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while index < text.endIndex {
            // Find the next word.
            guard let start = text[index...].firstIndex(where: isWordCharacter) else { break }
            // A Chinese or Japanese character is a word of its own.
            let end = isIdeographic(text[start]) ? text.index(after: start)
                : text[start...].firstIndex(where: { !isWordCharacter($0) || isIdeographic($0) }) ?? text.endIndex
            let folded = words(in: String(text[start..<end])).first ?? ""
            if let term = terms.first(where: { folded.hasPrefix($0) }) {
                ranges.append(start..<prefixEnd(of: term, inWordAt: start, end: end, in: text))
            }
            index = end
        }
        return ranges
    }

    private static func isIdeographic(_ character: Character) -> Bool {
        character.unicodeScalars.first.map { isIdeographic($0.value) } ?? false
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { $0.properties.isAlphabetic || $0.properties.numericType != nil }
    }

    /// Where the matched prefix ends in the original (unfolded) word.
    private static func prefixEnd(of term: String, inWordAt start: String.Index, end: String.Index, in text: String) -> String.Index {
        var cursor = start
        while cursor < end {
            let next = text.index(after: cursor)
            let folded = words(in: String(text[start..<next])).first ?? ""
            if folded.count >= term.count { return next }
            cursor = next
        }
        return end
    }
}
