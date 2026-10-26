import Foundation

/// Folio Markdown (SPEC §5.1): the canonical storage format for entry bodies.
///
/// A deliberately small dialect, implemented identically on iOS and web and pinned by
/// `shared/markdown-fixtures.json`:
/// - One block per line: `# ` heading, `- ` bullet, `1. ` numbered, `- [ ] ` / `- [x] `
///   checklist, `> ` quote, anything else a paragraph. Empty lines are empty paragraphs.
/// - Inline: `**bold**`, `_italic_` (`*italic*` also read), `<u>underline</u>`,
///   `~~strike~~`, `==highlight==`.
/// - `\` escapes any marker character. Unclosed markers are kept as literal text.
nonisolated enum MarkdownCodec {
    /// Characters that are always escaped in text.
    static let escapedCharacters: Set<Character> = ["\\", "*", "_", "~", "=", "<"]

    // MARK: Serialise

    static func markdown(from document: RichDocument) -> String {
        var lines: [String] = []
        var number = 0
        for block in document.blocks {
            number = block.kind == .numbered ? number + 1 : 0
            let body = inlineMarkdown(block.runs)
            switch block.kind {
            case .paragraph: lines.append(escapeLineStart(body))
            case .heading: lines.append("# " + body)
            case .bullet: lines.append("- " + body)
            case .numbered: lines.append("\(number). " + body)
            case .quote: lines.append("> " + body)
            case .checklist(let checked): lines.append((checked ? "- [x] " : "- [ ] ") + body)
            }
        }
        return lines.joined(separator: "\n")
    }

    static func inlineMarkdown(_ runs: [RichDocument.Run]) -> String {
        var output = ""
        var open: [RichDocument.InlineStyle] = []
        for run in normalized(runs) {
            // Close from the top of the stack until everything left is still wanted.
            while let index = open.firstIndex(where: { !run.styles.contains($0) }) {
                while open.count > index { output += open.removeLast().closing }
            }
            for style in RichDocument.InlineStyle.canonicalOrder where run.styles.contains(style) && !open.contains(style) {
                output += style.opening
                open.append(style)
            }
            output += escape(run.text)
        }
        while let style = open.popLast() { output += style.closing }
        return output
    }

    static func escape(_ text: String) -> String {
        var output = ""
        for character in text {
            if escapedCharacters.contains(character) { output.append("\\") }
            output.append(character)
        }
        return output
    }

    /// A paragraph whose text would read as a block marker gets its first character escaped.
    private static func escapeLineStart(_ line: String) -> String {
        if line.hasPrefix("# ") || line.hasPrefix("- ") || line.hasPrefix("> ") || line.hasPrefix("#") && line.count == 1 {
            return "\\" + line
        }
        if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty,
           line[line.index(after: dot)...].hasPrefix(" ") {
            return line[..<dot] + "\\" + line[dot...]
        }
        return line
    }

    // MARK: Parse

    static func document(from markdown: String) -> RichDocument {
        guard !markdown.isEmpty else { return RichDocument() }
        let lines = markdown.replacing("\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        return RichDocument(blocks: lines.map { block(from: String($0)) })
    }

    private static func block(from line: String) -> RichDocument.Block {
        let prefixes: [(String, RichDocument.BlockKind)] = [
            ("- [ ] ", .checklist(checked: false)), ("- [x] ", .checklist(checked: true)), ("- [X] ", .checklist(checked: true)),
            ("# ", .heading), ("- ", .bullet), ("> ", .quote),
        ]
        for (prefix, kind) in prefixes where line.hasPrefix(prefix) {
            return RichDocument.Block(kind, runs: inlineRuns(String(line.dropFirst(prefix.count))))
        }
        if let dot = line.firstIndex(of: "."), !line[..<dot].isEmpty, line[..<dot].allSatisfy(\.isASCIIDigit),
           line[line.index(after: dot)...].hasPrefix(" ") {
            return RichDocument.Block(.numbered, runs: inlineRuns(String(line[line.index(dot, offsetBy: 2)...])))
        }
        return RichDocument.Block(.paragraph, runs: inlineRuns(line))
    }

    private enum Token {
        case text(String)
        case marker(RichDocument.InlineStyle, opening: Bool, literal: String)
    }

    static func inlineRuns(_ text: String) -> [RichDocument.Run] {
        let tokens = tokenize(text)
        let matched = matchedMarkers(tokens)
        var runs: [RichDocument.Run] = []
        var active: Set<RichDocument.InlineStyle> = []
        for (index, token) in tokens.enumerated() {
            switch token {
            case .text(let string):
                runs.append(RichDocument.Run(string, active))
            case .marker(let style, let opening, let literal):
                if matched.contains(index) {
                    if opening { active.insert(style) } else { active.remove(style) }
                } else {
                    runs.append(RichDocument.Run(literal, active))
                }
            }
        }
        return normalized(runs)
    }

    /// Splits text into literal text and style markers. Toggle markers (`**`, `_`, `*`,
    /// `~~`, `==`) open when their style isn't active and close when it is.
    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""
        var active: Set<RichDocument.InlineStyle> = []
        let characters = Array(text)
        var i = 0
        func flush() {
            if !buffer.isEmpty { tokens.append(.text(buffer)); buffer = "" }
        }
        func toggle(_ style: RichDocument.InlineStyle, literal: String) {
            flush()
            let opening = !active.contains(style)
            if opening { active.insert(style) } else { active.remove(style) }
            tokens.append(.marker(style, opening: opening, literal: literal))
        }
        func lookahead(_ string: String) -> Bool {
            let target = Array(string)
            return i + target.count <= characters.count && Array(characters[i..<(i + target.count)]) == target
        }
        while i < characters.count {
            let c = characters[i]
            if c == "\\", i + 1 < characters.count {
                buffer.append(characters[i + 1]); i += 2
            } else if lookahead("**") {
                toggle(.bold, literal: "**"); i += 2
            } else if lookahead("~~") {
                toggle(.strikethrough, literal: "~~"); i += 2
            } else if lookahead("==") {
                toggle(.highlight, literal: "=="); i += 2
            } else if lookahead("<u>") {
                flush(); active.insert(.underline)
                tokens.append(.marker(.underline, opening: true, literal: "<u>")); i += 3
            } else if lookahead("</u>") {
                flush(); active.remove(.underline)
                tokens.append(.marker(.underline, opening: false, literal: "</u>")); i += 4
            } else if c == "_" || c == "*" {
                toggle(.italic, literal: String(c)); i += 1
            } else {
                buffer.append(c); i += 1
            }
        }
        flush()
        return tokens
    }

    /// Indices of markers that have a partner; the rest are literal text.
    private static func matchedMarkers(_ tokens: [Token]) -> Set<Int> {
        var matched = Set<Int>()
        var openIndex: [RichDocument.InlineStyle: Int] = [:]
        for (index, token) in tokens.enumerated() {
            guard case .marker(let style, let opening, _) = token else { continue }
            if opening {
                openIndex[style] = index
            } else if let start = openIndex.removeValue(forKey: style) {
                matched.insert(start)
                matched.insert(index)
            }
        }
        return matched
    }

    /// Merges neighbouring runs with identical styles and drops empty ones.
    static func normalized(_ runs: [RichDocument.Run]) -> [RichDocument.Run] {
        var output: [RichDocument.Run] = []
        for run in runs where !run.text.isEmpty {
            if let last = output.last, last.styles == run.styles {
                output[output.count - 1].text += run.text
            } else {
                output.append(run)
            }
        }
        return output
    }
}

nonisolated private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
