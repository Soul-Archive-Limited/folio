import Foundation
import Testing
@testable import Folio

@MainActor
@Suite("On this day subtitle (Batch I)")
struct OnThisDayTests {
    let day = DayKey(rawValue: "2026-10-29")!
    let gb = Locale(identifier: "en_GB")

    @Test("One, two and many years read naturally")
    func years() {
        #expect(SameDayOtherYears.subtitle(day: day, years: [2025], locale: gb) == "You wrote on 29 October in 2025")
        #expect(SameDayOtherYears.subtitle(day: day, years: [2025, 2023], locale: gb) == "You wrote on 29 October in 2023 and 2025")
        #expect(SameDayOtherYears.subtitle(day: day, years: [2025, 2019, 2023, 2023], locale: gb) == "You wrote on 29 October in 2019, 2023, and 2025"
                || SameDayOtherYears.subtitle(day: day, years: [2025, 2019, 2023, 2023], locale: gb) == "You wrote on 29 October in 2019, 2023 and 2025")
    }
}

@Suite("Dictation upgrades (Batch I)")
struct DictationUpgradeTests {
    @Test("English dictation follows the region", arguments: [("en_IN", "en_IN"), ("en_GB", "en_GB"), ("en_US", "en_US"), ("hi_IN", "hi_IN")])
    func regional(locale: String, expected: String) {
        #expect(DictationRules.regionalLocale(for: Locale(identifier: locale)).identifier == expected)
    }

    @Test("Hints are the name, categories and title, once each")
    func hints() {
        #expect(DictationRules.contextualStrings(name: "Sam", categories: ["Travel", "travel", "Work"], title: "Kochi trip")
            == ["Sam", "Travel", "Work", "Kochi trip"])
    }

    @Test("A tidy-up may only change punctuation and capitals")
    func tidyGuard() {
        #expect(DictationRules.onlyPunctuationChanged(from: "went to kochi today it rained", to: "Went to Kochi today. It rained."))
        #expect(!DictationRules.onlyPunctuationChanged(from: "went to kochi today", to: "I went to Kochi today."))
        #expect(!DictationRules.onlyPunctuationChanged(from: "same text", to: "same text"))
    }

    @Test("Elapsed time reads m:ss")
    func elapsed() {
        #expect(DictationRules.elapsedText(247) == "4:07")
        #expect(DictationRules.elapsedText(1800) == "30:00")
    }
}
