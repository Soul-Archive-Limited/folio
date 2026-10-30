import XCTest

/// SPEC §6.1 (Batch I redesign): every step, the first line landing on today, the keyboard never
/// following, a clean system back swipe, sign-in last, then the greeting and the tour.
final class OnboardingUITests: XCTestCase {
    @MainActor
    func testFirstLaunchJourneyEndsInTheTour() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-FolioNow", "2026-10-27T09:30", "-FolioToastSeconds", "15", "-hasOnboarded", "NO", "-FolioResetData", "YES", "-FolioTourStep", "0",
                               "-com.apple.TipKit.ResetDatastore", "1", "-seasonEffect", "auto",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()
        let pace = ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1" ? 1.4 : 0.4

        // 1 · Welcome
        XCTAssertTrue(app.staticTexts["Your days, kept."].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: pace * 2)
        app.buttons["Get started"].press(forDuration: 0.15)

        // 2 · The interactive moment: a first line lands on today.
        let line = app.textFields["onboarding.firstLine"]
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        line.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "a tap on the field focuses it")
        line.typeText("First page in my new diary")
        app.staticTexts["October 2026"].tap()  // a tap outside (on the month): the keyboard goes
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        app.buttons["Add to today"].press(forDuration: 0.15)
        XCTAssertTrue(app.staticTexts["It's on your calendar."].waitForExistence(timeout: 5), "the line landed on today")
        Thread.sleep(forTimeInterval: pace * 2)
        app.buttons["Continue"].press(forDuration: 0.15)

        // 3 · What you'll keep
        XCTAssertTrue(app.staticTexts["What will you keep here?"].waitForExistence(timeout: 10))
        app.buttons["Travel"].press(forDuration: 0.15)
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Memories"].press(forDuration: 0.15)
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Continue"].press(forDuration: 0.15)

        // 4 · Name and picture
        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        name.typeText("Sam")
        app.staticTexts["What should we call you?"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "a tap outside dismisses")
        app.buttons["Spark"].press(forDuration: 0.15)
        Thread.sleep(forTimeInterval: pace)
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        name.typeText("\n")  // Return continues while the keyboard covers the button
        XCTAssertTrue(app.staticTexts["Your look"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "the keyboard never follows to the next step")

        // Back with the system swipe: a clean landing on the name step, nothing lost (bug 2).
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssertTrue(app.staticTexts["What should we call you?"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(name.value as? String, "Sam")
        XCTAssertFalse(app.staticTexts["Your look"].exists, "nothing left half-way between steps")
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Continue"].firstMatch.press(forDuration: 0.15)

        // 5 · Look
        XCTAssertTrue(app.staticTexts["Your look"].waitForExistence(timeout: 10))
        app.buttons["Dark"].press(forDuration: 0.15)
        Thread.sleep(forTimeInterval: pace * 2)
        app.buttons["Match iPhone"].press(forDuration: 0.15)
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Continue"].press(forDuration: 0.15)

        // 6 · Sync, last, with Not now
        XCTAssertTrue(app.staticTexts["Keep your diary in sync?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Continue with Apple"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        app.buttons["Continue with email"].tap()
        XCTAssertTrue(app.textFields["Email address"].waitForExistence(timeout: 10), "email sign-in opens")
        Thread.sleep(forTimeInterval: pace)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Keep your diary in sync?"].waitForExistence(timeout: 10))
        app.buttons["Not now — keep it on this iPhone"].tap()

        // Greeting, then the tour's first step on the calendar, with its count.
        XCTAssertTrue(app.staticTexts["Your month"].waitForExistence(timeout: 30), "tour starts after the greeting")
        XCTAssertEqual(app.staticTexts["tour.count"].label.lowercased(), "step 1 of 6")
        XCTAssertTrue(app.staticTexts["Tap a day"].waitForExistence(timeout: 15), "step 1 advances by itself")
        Thread.sleep(forTimeInterval: pace * 2)
    }
}
