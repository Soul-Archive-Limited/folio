import Foundation
import Testing
@testable import Folio

/// Batch E fix 4: the tour moves itself between screens, counts its steps, and never
/// closes a composer that has writing in it.
@MainActor
@Suite("Guided tour")
struct TourModelTests {
    final class FakeApp {
        var tab: AppTab = .calendar
        var composerOpen = false
        var navigator: TourNavigator {
            TourNavigator(selectedTab: { self.tab }, select: { self.tab = $0 },
                          isComposerOpen: { self.composerOpen },
                          openComposer: { self.composerOpen = true }, closeComposer: { self.composerOpen = false })
        }
    }

    let defaults = UserDefaults(suiteName: "tour-\(UUID().uuidString)")!

    private func makeTour(_ app: FakeApp) -> TourModel {
        let tour = TourModel(defaults: defaults, settle: .zero)
        tour.navigator = app.navigator
        return tour
    }

    @Test("Six steps, each knows its number")
    func count() {
        #expect(TourStep.allCases.count == 6)
        #expect(TourStep.tapDay.rawValue == 2 && TourStep.profile.isLast)
    }

    @Test("Next from the composer step closes an empty composer and switches to To-do")
    func composerToTodo() {
        let app = FakeApp()
        let tour = makeTour(app)
        tour.start()
        tour.go(to: .composerTools)
        #expect(app.composerOpen)
        tour.next()
        #expect(tour.current == .todo)
        #expect(!app.composerOpen && app.tab == .todo)
        tour.next()
        #expect(app.tab == .profile)
        tour.next()
        #expect(!tour.isRunning)
    }

    @Test("A composer with writing in it is never closed for the user")
    func keepsWriting() {
        let app = FakeApp()
        let tour = makeTour(app)
        tour.go(to: .composerTools)
        tour.composerChanged(hasChanges: true)
        tour.next()
        #expect(app.composerOpen, "still open")
        #expect(tour.current == .composerTools)
        app.composerOpen = false
        tour.didCloseComposer()
        #expect(tour.current == .todo && app.tab == .todo)
    }

    @Test("Back returns to the previous step's screen")
    func back() {
        let app = FakeApp()
        let tour = makeTour(app)
        tour.go(to: .todo)
        tour.back()
        #expect(tour.current == .composerTools && app.composerOpen && app.tab == .calendar)
    }

    @Test("Action steps advance only on their own action")
    func actions() {
        let tour = makeTour(FakeApp())
        tour.start()
        tour.didSelectDay()
        #expect(tour.current == .month, "tapping a day on step 1 doesn't skip ahead")
        tour.next()
        tour.didSelectDay()
        #expect(tour.current == .add)
        tour.didOpenComposer()
        #expect(tour.current == .composerTools)
    }

    @Test("A tour left half-way resumes; in the composer it resumes at +")
    func resume() {
        let tour = makeTour(FakeApp())
        tour.go(to: .composerTools)
        let again = TourModel(defaults: defaults, settle: .zero)
        again.resumeIfNeeded()
        #expect(again.current == .add)
        again.skip()
        let third = TourModel(defaults: defaults, settle: .zero)
        third.resumeIfNeeded()
        #expect(!third.isRunning, "skipped tours never come back")
    }
}
