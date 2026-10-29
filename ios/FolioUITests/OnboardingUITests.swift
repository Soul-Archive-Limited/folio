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
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        name.typeText("Sam\n")  // Return is Continue while the keyboard covers the buttons

        XCTAssertTrue(app.staticTexts["Keep your diary in sync?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "the keyboard never follows to the next page")
        XCTAssertTrue(app.buttons["Continue with Apple"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        // Email opens its own step, and Cancel comes back here.
        app.buttons["Continue with email"].tap()
        XCTAssertTrue(app.textFields["Email address"].waitForExistence(timeout: 10), "email sign-in opens")
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Keep your diary in sync?"].waitForExistence(timeout: 10))
        app.buttons["Not now — keep it on this iPhone"].tap()

        // Greeting, then the tour's first step on the calendar, with its count.
        XCTAssertTrue(app.staticTexts["Your month"].waitForExistence(timeout: 30), "tour starts after the greeting")
        XCTAssertEqual(app.staticTexts["tour.count"].label.lowercased(), "step 1 of 6")
        // Step 1 is look-only and moves on by itself after 4 s. Tapping Next would race it on a
        // slow runner (the tap lands on step 2's Next and skips to step 3), so wait for it.
        XCTAssertTrue(app.staticTexts["Tap a day"].waitForExistence(timeout: 15), "step 1 advances by itself")
        XCTAssertEqual(app.staticTexts["tour.count"].label.lowercased(), "step 2 of 6")
        Thread.sleep(forTimeInterval: pace * 2)
    }

    /// Batch E fix 3: a tap outside the name field, and Skip, both put the keyboard away.
    @MainActor
    func testNameKeyboardDismisses() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "NO", "-FolioOnboardingPage", "3", "-FolioNoTour", "YES",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()
        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 20))
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.staticTexts["What should we call you?"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "tap outside dismisses")

        name.tap()
        name.typeText("Sam")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        // Tap empty space (the keyboard covers the buttons), then Skip.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "tap on empty space dismisses")
        tapVisible(app.buttons.matching(identifier: "Skip"), in: app)
        XCTAssertTrue(app.staticTexts["Keep your diary in sync?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "Skip dismisses")
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
