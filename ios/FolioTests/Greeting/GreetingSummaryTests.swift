import Foundation
import Testing
@testable import Folio

@Suite("Greeting summary and launch policy")
struct GreetingSummaryTests {
    @Test("All-zero summary is quiet and has no text")
    func quiet() {
        #expect(GreetingSummary.empty.isQuiet)
        #expect(GreetingSummary.empty.text == nil)
    }

    @Test("Any non-zero part makes the summary non-quiet")
    func nonQuiet() {
        #expect(!GreetingSummary(tasksToday: 1).isQuiet)
        #expect(!GreetingSummary(tasksOverdue: 2).isQuiet)
        #expect(!GreetingSummary(pagesThisWeek: 3).isQuiet)
        #expect(GreetingSummary(pagesThisWeek: 3).text != nil)
    }

    @Test("Greeting is skipped when resumed within 10 minutes")
    func resumeWindow() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(GreetingLaunchPolicy.shouldShow(now: now, lastBackgroundAt: nil))
        #expect(!GreetingLaunchPolicy.shouldShow(now: now, lastBackgroundAt: now.addingTimeInterval(-60)))
        #expect(!GreetingLaunchPolicy.shouldShow(now: now, lastBackgroundAt: now.addingTimeInterval(-599)))
        #expect(GreetingLaunchPolicy.shouldShow(now: now, lastBackgroundAt: now.addingTimeInterval(-600)))
    }

    @Test("Word reveal tags every word and sizes its duration at 40 ms per word")
    func wordReveal() {
        let (_, count) = WordRevealRenderer.text("Morning, Sam. Coffee first?")
        #expect(count == 4)
        #expect(abs(WordRevealRenderer.totalDuration(wordCount: 4) - (3 * 0.04 + 0.28)) < 0.0001)
    }

    @Test("Greeting factory remembers the greeting and honours the resume window")
    func factory() throws {
        let defaults = try #require(UserDefaults(suiteName: "GreetingFactoryTests"))
        defaults.removePersistentDomain(forName: "GreetingFactoryTests")
        let factory = GreetingFactory(defaults: defaults)
        let now = Date.now
        let model = try #require(factory.makeIfNeeded(now: now, name: "Sam", summary: .empty))
        #expect(defaults.string(forKey: PreferenceKeys.lastGreetingID) != nil)
        #expect(!model.greeting.isEmpty)
        defaults.set(now.addingTimeInterval(-30), forKey: PreferenceKeys.lastBackgroundAt)
        #expect(factory.makeIfNeeded(now: now, name: "Sam", summary: .empty) == nil)
        #expect(factory.makeIfNeeded(now: now, name: "Sam", summary: .empty, force: true) != nil)
    }
}
