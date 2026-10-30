import SwiftUI
import Testing
@testable import Folio

@MainActor
@Suite("Share as image → All pages: nothing is cut (Batch I)")
struct StoryPagesTests {
    private func content(words: Int) -> EntryShareContent {
        let text = (0..<words).map { "word\($0)" }.joined(separator: " ")
        return EntryShareContent(title: "Long day", dateLine: "Thursday 29 October 2026", plainText: text)
    }

    @Test("A short entry is one page")
    func shortIsOnePage() {
        #expect(EntryStoryPages.pageCount(content: content(words: 30), hasPhoto: true, writingFont: .newYork) == 1)
    }

    @Test("A long entry flows over several pages and every word appears once, in order")
    func longKeepsEveryWord() {
        let long = content(words: 1500)
        let pages = EntryStoryPages.pages(content: long, hasPhoto: true, writingFont: .newYork)
        #expect(pages.count > 3)
        let rejoined = pages.joined(separator: " ").split(separator: " ").map(String.init)
        #expect(rejoined == long.plainText.split(separator: " ").map(String.init))
    }

    @Test("Pages render at 1080 × 1920")
    func renderSize() throws {
        let images = EntryStoryPages.images(content: content(words: 600), photo: nil, writingFont: .sfPro)
        let first = try #require(images.first)
        #expect(first.size.width * first.scale == 1080)
        #expect(first.size.height * first.scale == 1920)
    }
}
