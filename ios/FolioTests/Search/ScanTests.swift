import Foundation
import Testing
import Vision
@testable import Folio

@Suite("Scanning paper pages")
struct ScanTests {
    let today = DayKey(year: 2026, month: 11, day: 5)!

    @Test("Dates at the top of a page: written, numeric day-first, US month-first, Devanagari digits")
    func dates() {
        #expect(PageDateFinder.suggest(in: "Tuesday, 12 March 2019\nWalked…", today: today) == DayKey(year: 2019, month: 3, day: 12))
        #expect(PageDateFinder.suggest(in: "3/4/2019 rain all day", today: today, monthFirst: false) == DayKey(year: 2019, month: 4, day: 3))
        #expect(PageDateFinder.suggest(in: "3/4/2019 rain all day", today: today, monthFirst: true) == DayKey(year: 2019, month: 3, day: 4))
        #expect(PageDateFinder.suggest(in: "१२.०३.२०१९ आज", today: today, monthFirst: false) == DayKey(year: 2019, month: 3, day: 12))
        #expect(PageDateFinder.suggest(in: "12/03/99", today: today, monthFirst: false) == DayKey(year: 1999, month: 3, day: 12))
    }

    @Test("No date, an impossible date, or a far-future date suggests nothing")
    func noDate() {
        #expect(PageDateFinder.suggest(in: "Dear diary, nothing much happened.", today: today) == nil)
        #expect(PageDateFinder.suggest(in: "31/02/2019", today: today, monthFirst: false) == nil)
        #expect(PageDateFinder.suggest(in: "01/01/2030 plans", today: today, monthFirst: false) == nil)
    }

    @Test("Reads the sample page on the device: English and Hindi lines, top to bottom, and its date")
    func readSamplePage() async throws {
        let url = try #require(Bundle(for: ScanBundleToken.self).url(forResource: "sample-diary-page", withExtension: "jpg"))
        let text = try await PageReader.read(Data(contentsOf: url))
        #expect(text.localizedCaseInsensitiveContains("river"))
        // Hindi text recognition arrived after iOS 26.5 (macOS 27 has it): checked only where supported.
        if RecognizeTextRequest().supportedRecognitionLanguages.contains(where: { $0.minimalIdentifier == "hi" }) {
            #expect(text.contains("नदी"))
        }
        let lines = text.components(separatedBy: "\n")
        let first = try #require(lines.firstIndex { $0.localizedCaseInsensitiveContains("march") })
        let later = try #require(lines.firstIndex { $0.localizedCaseInsensitiveContains("kheer") })
        #expect(first < later)
        #expect(PageDateFinder.suggest(in: text, today: today) == DayKey(year: 2019, month: 3, day: 12))
    }
}

private final class ScanBundleToken {}
