import Foundation

/// The formatted-text model shared by the iOS editor, the web editor and storage
/// (SPEC §5.1). It allows exactly the supported styles, so anything outside them can't be
/// represented, let alone saved.
nonisolated struct RichDocument: Equatable, Codable, Sendable {
    var blocks: [Block]

    init(blocks: [Block] = []) {
        self.blocks = blocks
    }

    struct Block: Equatable, Codable, Sendable {
        var kind: BlockKind
        var runs: [Run]

        init(_ kind: BlockKind = .paragraph, runs: [Run] = []) {
            self.kind = kind
            self.runs = runs
        }

        enum CodingKeys: String, CodingKey { case kind = "type", checked, runs }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .kind)
            switch type {
            case "paragraph": kind = .paragraph
            case "heading": kind = .heading
            case "bullet": kind = .bullet
            case "numbered": kind = .numbered
            case "quote": kind = .quote
            case "checklist": kind = .checklist(checked: try container.decodeIfPresent(Bool.self, forKey: .checked) ?? false)
            default: throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown block \(type)")
            }
            runs = try container.decodeIfPresent([Run].self, forKey: .runs) ?? []
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind.typeName, forKey: .kind)
            if case .checklist(let checked) = kind { try container.encode(checked, forKey: .checked) }
            try container.encode(runs, forKey: .runs)
        }

        /// Plain text of the block, e.g. for previews.
        var text: String { runs.map(\.text).joined() }
    }

    enum BlockKind: Equatable, Sendable {
        case paragraph, heading, bullet, numbered, quote
        case checklist(checked: Bool)

        var typeName: String {
            switch self {
            case .paragraph: "paragraph"
            case .heading: "heading"
            case .bullet: "bullet"
            case .numbered: "numbered"
            case .quote: "quote"
            case .checklist: "checklist"
            }
        }
    }

    struct Run: Equatable, Codable, Sendable {
        var text: String
        var styles: Set<InlineStyle>

        init(_ text: String, _ styles: Set<InlineStyle> = []) {
            self.text = text
            self.styles = styles
        }

        enum CodingKeys: CodingKey { case text, styles }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decode(String.self, forKey: .text)
            styles = Set(try container.decodeIfPresent([InlineStyle].self, forKey: .styles) ?? [])
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encode(InlineStyle.canonicalOrder.filter(styles.contains), forKey: .styles)
        }
    }

    enum InlineStyle: String, Codable, Sendable, CaseIterable {
        case bold, italic, underline, strikethrough, highlight

        /// Outermost first. Serialisation opens markers in this order, so output is canonical.
        static let canonicalOrder: [InlineStyle] = [.underline, .highlight, .strikethrough, .bold, .italic]

        var opening: String {
            switch self {
            case .bold: "**"
            case .italic: "_"
            case .underline: "<u>"
            case .strikethrough: "~~"
            case .highlight: "=="
            }
        }

        var closing: String { self == .underline ? "</u>" : opening }
    }

    /// Plain text of the whole document, one block per line.
    var plainText: String { blocks.map(\.text).joined(separator: "\n") }
}
