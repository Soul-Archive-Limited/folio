import Foundation
import SwiftUI
import Testing
@testable import Folio

/// Batch E fix 9: shares say exactly what goes out, and only this entry's content.
@MainActor
@Suite("Sharing an entry")
struct EntryShareTests {
    let content = EntryShareContent(title: "Train to Edinburgh", dateLine: "Sunday 25 October 2026",
                                    plainText: "Four hours of fields, rain and a very good book.\n☑ book seats")

    @Test("Text share is title, date and text — no links")
    func text() {
        #expect(content.text == "Train to Edinburgh\n\nSunday 25 October 2026\n\nFour hours of fields, rain and a very good book.\n☑ book seats")
        #expect(!content.text.contains("http") && !content.text.contains("folio://"))
    }

    @Test("Untitled entries get a dated preview title")
    func untitled() {
        let untitled = EntryShareContent(title: "", dateLine: "Sunday 25 October 2026", plainText: "Hello")
        #expect(untitled.previewTitle.contains("25 October 2026"))
        #expect(untitled.text == "Sunday 25 October 2026\n\nHello")
    }

    @Test("The image card keeps to the opening lines")
    func openingLines() {
        let long = EntryShareContent(title: "", dateLine: "", plainText: String(repeating: "word ", count: 200))
        #expect(long.openingLines.count <= 281)
        #expect(long.openingLines.hasSuffix("…"))
    }

    @Test("The image card renders 1080 px wide")
    func card() throws {
        let data = try #require(EntryShareCard.png(content: content, photo: nil, writingFont: .newYork))
        let image = try #require(UIImage(data: data))
        #expect(image.size.width * image.scale == 1080)
        if let folder = ProcessInfo.processInfo.environment["FOLIO_SHOTS"] {
            try data.write(to: URL(fileURLWithPath: folder).appending(path: "09-after-share-card-text-only.png"))
        }
    }
}
