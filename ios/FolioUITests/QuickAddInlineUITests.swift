import XCTest

/// Batch C fix: when the tab bar minimises on scroll, the To-do quick-add bar drops into the
/// tab bar's row beside the small circle (no gap), still takes taps there, and comes back up
/// above the keyboard while typing.
final class QuickAddInlineUITests: XCTestCase {
    @MainActor
    func testQuickAddFollowsTheMinimisedTabBar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioResetData", "YES",
                               "-FolioSampleData", "YES", "-FolioSkipGreeting", "YES", "-FolioTab", "todo",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()

        let quickAdd = app.textFields["Add a task…"]
        XCTAssertTrue(quickAdd.waitForExistence(timeout: 8))
        let resting = quickAdd.frame
        let tabBar = app.tabBars.firstMatch
        XCTAssertLessThanOrEqual(resting.maxY, tabBar.frame.minY + 1, "at rest the bar sits above the tab bar")

        app.swipeUp(velocity: .slow)
        let deadline = Date.now.addingTimeInterval(4)
        while quickAdd.frame.minY < resting.minY + 30, Date.now < deadline { usleep(100_000) }
        XCTAssertGreaterThan(quickAdd.frame.minY, resting.minY + 30, "drops into the tab bar's row")
        XCTAssertGreaterThan(quickAdd.frame.minX, resting.minX + 40, "moves in past the minimised tab button")

        quickAdd.tap()
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: quickAdd)
        wait(for: [focused], timeout: 4)
        // A Simulator with a hardware keyboard attached shows no software keyboard.
        let keyboard = app.keyboards.firstMatch
        if keyboard.waitForExistence(timeout: 3) {
            sleep(1)
            XCTAssertLessThanOrEqual(quickAdd.frame.maxY, keyboard.frame.minY + 1, "rides above the keyboard")
        }
    }
}
