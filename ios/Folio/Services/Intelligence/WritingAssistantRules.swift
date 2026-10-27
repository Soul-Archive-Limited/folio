import Foundation

/// Limits for the ✦ writing tools (SPEC §9): one request at a time, at least 1.5 s apart,
/// and no more than about 6,000 characters of input.
nonisolated struct RequestGate: Sendable {
    static let minimumInterval: Duration = .milliseconds(1500)
    static let maximumInput = 6000

    private(set) var lastStart: ContinuousClock.Instant?

    /// True if a request may start at `now`; records it when it does.
    mutating func allows(at now: ContinuousClock.Instant) -> Bool {
        if let lastStart, now - lastStart < Self.minimumInterval { return false }
        lastStart = now
        return true
    }

    /// Trims input to the limit at a word boundary.
    static func clip(_ text: String) -> String {
        guard text.count > maximumInput else { return text }
        let prefix = text.prefix(maximumInput)
        if let space = prefix.lastIndex(where: \.isWhitespace) { return String(prefix[..<space]) }
        return String(prefix)
    }
}

/// A word-level diff for the "Polish grammar" preview: what stays, what goes, what's new.
nonisolated enum WordDiff {
    enum Change: Equatable, Sendable {
        case same(String)
        case removed(String)
        case added(String)
    }

    /// Longest-common-subsequence over words, keeping each word's trailing space so the
    /// preview reads naturally.
    static func changes(from old: String, to new: String) -> [Change] {
        let a = tokens(old), b = tokens(new)
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var changes: [Change] = []
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] {
                changes.append(.same(a[i])); i += 1; j += 1
            } else if i < a.count, j == b.count || table[i + 1][j] >= table[i][j + 1] {
                // Removals first, so a replaced word reads "old → new".
                changes.append(.removed(a[i])); i += 1
            } else {
                changes.append(.added(b[j])); j += 1
            }
        }
        return merged(changes)
    }

    /// The preview compares words, not Markdown: emphasis markers are left out of it.
    static func plain(_ markdown: String) -> String {
        var text = markdown
        for marker in ["**", "~~", "==", "*"] { text = text.replacingOccurrences(of: marker, with: "") }
        return text
    }

    private static func tokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character.isWhitespace { tokens.append(current); current = "" }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Joins neighbouring changes of the same kind into one run.
    private static func merged(_ changes: [Change]) -> [Change] {
        var result: [Change] = []
        for change in changes {
            switch (result.last, change) {
            case (.same(let a)?, .same(let b)): result[result.count - 1] = .same(a + b)
            case (.removed(let a)?, .removed(let b)): result[result.count - 1] = .removed(a + b)
            case (.added(let a)?, .added(let b)): result[result.count - 1] = .added(a + b)
            default: result.append(change)
            }
        }
        return result
    }
}
