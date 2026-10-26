import Foundation
import Testing
@testable import Folio

/// The shared fixtures pin Folio Markdown for iOS and web (SPEC §5.1).
@Suite("Markdown codec")
struct MarkdownCodecTests {
    nonisolated struct Fixtures: Decodable, Sendable {
        struct Case: Decodable, Sendable, CustomTestStringConvertible {
            let name: String
            let markdown: String
            let document: RichDocument
            let serialized: String?
            var testDescription: String { name }
        }
        let canonical: [Case]
        let lenient: [Case]
    }

    nonisolated static let fixtures: Fixtures = {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "markdown-fixtures", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let fixtures = try? JSONDecoder().decode(Fixtures.self, from: data) else {
            return Fixtures(canonical: [], lenient: [])
        }
        return fixtures
    }()

    @Test("Fixtures load")
    func fixturesLoad() {
        #expect(Self.fixtures.canonical.count >= 20)
    }

    @Test("Canonical cases parse and serialise exactly", arguments: fixtures.canonical)
    func canonical(_ fixture: Fixtures.Case) {
        #expect(MarkdownCodec.document(from: fixture.markdown) == fixture.document)
        #expect(MarkdownCodec.markdown(from: fixture.document) == fixture.markdown)
    }

    @Test("Lenient input parses and normalises", arguments: fixtures.lenient)
    func lenient(_ fixture: Fixtures.Case) {
        #expect(MarkdownCodec.document(from: fixture.markdown) == fixture.document)
        #expect(MarkdownCodec.markdown(from: fixture.document) == fixture.serialized)
    }

    @Test("Any document survives a round trip", arguments: 0..<200)
    func randomRoundTrip(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed))
        let document = Self.randomDocument(using: &generator)
        let markdown = MarkdownCodec.markdown(from: document)
        #expect(MarkdownCodec.document(from: markdown) == Self.normalized(document), "\(markdown)")
    }

    static func randomDocument(using generator: inout SeededGenerator) -> RichDocument {
        let kinds: [RichDocument.BlockKind] = [.paragraph, .heading, .bullet, .numbered, .quote, .checklist(checked: true), .checklist(checked: false)]
        let words = ["sun", "a*b", "x_y", "~", "==", "<u>", "\\", "- not", "# no", "1. no", "café", " ", "end."]
        let styles = RichDocument.InlineStyle.allCases
        let blocks = (0..<Int.random(in: 1...4, using: &generator)).map { _ in
            let runs = (0..<Int.random(in: 1...5, using: &generator)).map { _ in
                RichDocument.Run(words.randomElement(using: &generator) ?? "x",
                                 Set(styles.filter { _ in Bool.random(using: &generator) }))
            }
            return RichDocument.Block(kinds.randomElement(using: &generator) ?? .paragraph, runs: runs)
        }
        return RichDocument(blocks: blocks)
    }

    static func normalized(_ document: RichDocument) -> RichDocument {
        RichDocument(blocks: document.blocks.map { RichDocument.Block($0.kind, runs: MarkdownCodec.normalized($0.runs)) })
    }
}

private final class BundleToken {}
