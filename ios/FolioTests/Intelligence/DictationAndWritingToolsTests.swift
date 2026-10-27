import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Folio

@Suite("Dictation rules (SPEC §8)")
struct DictationRulesTests {
    @Test("Stops after 2 minutes of silence or 30 minutes in all")
    func autoStop() {
        #expect(!DictationRules.shouldStop(silentFor: .seconds(119), runningFor: .seconds(600)))
        #expect(DictationRules.shouldStop(silentFor: .seconds(120), runningFor: .seconds(130)))
        #expect(DictationRules.shouldStop(silentFor: .zero, runningFor: .seconds(1800)))
    }

    @Test("Committed phrases are spaced from the text before them")
    func spacing() {
        #expect(DictationRules.insertion("went for a walk", after: nil) == "went for a walk")
        #expect(DictationRules.insertion("went for a walk", after: "\n") == "went for a walk")
        #expect(DictationRules.insertion("went for a walk ", after: "y") == " went for a walk")
        #expect(DictationRules.insertion("went", after: " ") == "went")
        #expect(DictationRules.insertion(", then home", after: "k") == ", then home")
        #expect(DictationRules.insertion("   ", after: "k").isEmpty)
    }

    @Test("Mic level maps quiet to 0 and loud to 1")
    func level() {
        let silent = [Float](repeating: 0, count: 512)
        let loud = [Float](repeating: 0.5, count: 512)
        silent.withUnsafeBufferPointer { #expect(DictationRules.level(of: $0) == 0) }
        loud.withUnsafeBufferPointer { #expect(DictationRules.level(of: $0) == 1) }
    }

    @MainActor
    @Test("Repeat taps within 600 ms are ignored")
    func repeatTaps() {
        let session = DictationSession()
        let start = ContinuousClock.now
        #expect(session.acceptsTap(at: start))
        #expect(!session.acceptsTap(at: start + .milliseconds(300)))
        #expect(session.acceptsTap(at: start + .milliseconds(1000)))
    }
}

@MainActor
@Suite("Dictation into the composer (SPEC §6.11)")
struct DictationInsertTests {
    @Test("Finals go at the cursor, spaced, or at the end before the editor had focus")
    func insertAtCursor() {
        let model = ComposerModel(day: DayKey(date: .now, calendar: .current), categoryID: nil, writingFont: .newYork,
                                  drafts: DraftStore(directory: .temporaryDirectory.appending(path: UUID().uuidString)))
        model.body = AttributedString("Rain all day.")
        model.insertDictation("Stayed in and read")
        #expect(String(model.body.characters) == "Rain all day. Stayed in and read")

        model.body = AttributedString("Rain. Soup.")
        let afterRain = model.body.characters.index(model.body.startIndex, offsetBy: 5)
        model.selection = AttributedTextSelection(insertionPoint: afterRain)
        model.insertDictation("Then sun")
        #expect(String(model.body.characters) == "Rain. Then sun Soup.")
    }
}

@Suite("Writing tools limits (SPEC §9)")
struct WritingToolsRulesTests {
    @Test("Requests are at least 1.5 s apart")
    func gate() {
        var gate = RequestGate()
        let start = ContinuousClock.now
        let first = gate.allows(at: start)
        let tooSoon = gate.allows(at: start + .milliseconds(1400))
        let later = gate.allows(at: start + .milliseconds(1600))
        #expect(first && !tooSoon && later)
    }

    @Test("Input is clipped to about 6,000 characters at a word boundary")
    func clip() {
        let long = String(repeating: "word ", count: 2000)
        let clipped = RequestGate.clip(long)
        #expect(clipped.count <= RequestGate.maximumInput)
        #expect(clipped.hasSuffix("word"))
        #expect(RequestGate.clip("short") == "short")
    }

    @Test("Grammar diff shows removals before additions and keeps unchanged words")
    func diff() {
        let changes = WordDiff.changes(from: "I has a idea today", to: "I had an idea today")
        #expect(changes == [.same("I "), .removed("has a "), .added("had an "), .same("idea today")])
        #expect(WordDiff.changes(from: "Same words", to: "Same words") == [.same("Same words")])
    }

    @Test("The preview ignores Markdown markers")
    func plain() {
        #expect(WordDiff.plain("The light was **perfect** and ~~grey~~") == "The light was perfect and grey")
    }

    @MainActor
    @Test("Unavailable reasons each have an explanation for Profile")
    func explanations() {
        let reasons: [WritingAssistant.Availability.Reason] = [.deviceNotEligible, .appleIntelligenceOff, .modelNotReady, .language]
        #expect(Set(reasons.map { "\(ProfileIntelligenceSection.explanation(for: .unavailable($0)))" }).count == reasons.count)
    }
}
