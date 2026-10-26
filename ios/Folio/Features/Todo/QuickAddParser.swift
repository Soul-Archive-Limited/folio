import Foundation

/// Reads "today" / "tomorrow" out of a quick-add line (SPEC §6.7): "Call Mum tomorrow" is a
/// task called "Call Mum" for tomorrow. Only whole words at the start or end count, so
/// "Today's papers" stays as typed.
nonisolated enum QuickAddParser {
    struct Result: Equatable {
        let title: String
        let day: DayKey?
    }

    static func parse(_ text: String, today: DayKey) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords: [(String, Int)] = [
            (String(localized: "today").lowercased(), 0),
            (String(localized: "tomorrow").lowercased(), 1),
        ]
        var words = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        for (keyword, offset) in keywords {
            if let last = words.last, normalised(last) == keyword, words.count > 1 {
                words.removeLast()
                return Result(title: words.joined(separator: " "), day: today.adding(days: offset))
            }
            if let first = words.first, normalised(first) == keyword, words.count > 1 {
                words.removeFirst()
                return Result(title: words.joined(separator: " "), day: today.adding(days: offset))
            }
        }
        return Result(title: trimmed, day: nil)
    }

    private static func normalised(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }
}
