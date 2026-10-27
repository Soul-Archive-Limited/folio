import XCTest

/// SPEC §6.1 steps 1–5 and 8: the first-launch journey ends on the calendar with the tour's
/// first tip. Also checks that sign-in buttons explain they aren't ready yet (DEBUG).
final class OnboardingUITests: XCTestCase {
    @MainActor
    func testFirstLaunchJourneyEndsInTheTour() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-FolioToastSeconds", "15", "-hasOnboarded", "NO", "-FolioResetData", "YES", "-FolioTourStep", "0",
                               "-com.apple.TipKit.ResetDatastore", "1",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your days, kept."].waitForExistence(timeout: 20))
        let pace = ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1" ? 1.6 : 0.6
        for _ in 0..<3 {
            tapVisible(app.buttons.matching(identifier: "Continue"), in: app)
            Thread.sleep(forTimeInterval: pace)
        }

        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Sam\n")  // Return submits, like Continue (which the keyboard covers)

        XCTAssertTrue(app.staticTexts["Keep your diary in sync?"].waitForExistence(timeout: 10))
        app.buttons["Continue with Apple"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Available after Phase 10"].waitForExistence(timeout: 10),
                      "sign-in isn't wired yet, and says so")
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Not now — keep it on this iPhone"].tap()

        // Greeting, then the tour's first tip on the calendar.
        XCTAssertTrue(app.staticTexts["Your month"].waitForExistence(timeout: 30), "tour starts after the greeting")
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Next"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Tap a day"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: pace * 2)
    }

    /// Pages off screen keep their buttons in the tree; tap the one that's on screen.
    @MainActor
    private func tapVisible(_ query: XCUIElementQuery, in app: XCUIApplication) {
        let screen = app.frame
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            // Frame check rather than `isHittable`, which fails outright if a page moves mid-check.
            if let button = query.allElementsBoundByIndex.first(where: { screen.contains($0.frame) }) {
                button.tap()
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("no visible button")
    }
}
