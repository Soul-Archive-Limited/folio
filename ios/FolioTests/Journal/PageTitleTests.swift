import Foundation
import Testing
@testable import Folio

/// Batch O (owner): a page is never listed as "Untitled".
@Suite("Page names")
@MainActor
struct PageTitleTests {
    @Test("Title, else first line, else photos, else empty")
    func names() {
        let day = DayKey(rawValue: "2026-11-14")!
        #expect(Entry(title: "Long walk", bodyMarkdown: "Along the river.", day: day).displayTitle == "Long walk")
        #expect(Entry(title: " ", bodyMarkdown: "\n**Saw a heron** standing still.\nSecond", day: day).displayTitle == "Saw a heron standing still.")
        #expect(Entry(title: "", bodyMarkdown: "", day: day).displayTitle == "Empty page")
        #expect(Entry.untitledName(photoCount: 1) == "A photo")
        #expect(Entry.untitledName(photoCount: 3) == "3 photos")
    }
}
