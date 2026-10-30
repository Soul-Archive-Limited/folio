import XCTest

/// Tour step 4 lives in the composer sheet (owner's test, Batch I: its ring didn't line up).
/// Opening the composer from step 3 shows step 4's card and its ring; a screenshot goes to
/// `TEST_RUNNER_FOLIO_SHOTS` when set.
final class TourComposerStepUITests: XCTestCase {
    @MainActor
    func testComposerStepShowsItsCard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-FolioSkipGreeting", "YES", "-FolioNow", "2026-10-27T09:30",
                               "-FolioTourStep", "3", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Write your first page"].waitForExistence(timeout: 20))
        app.buttons["Next"].press(forDuration: 0.15)
        let title = app.staticTexts["Photos, categories, your voice"]
        XCTAssertTrue(title.waitForExistence(timeout: 6), "step 4's card shows in the composer")
        Thread.sleep(forTimeInterval: 0.6)
        if let folder = ProcessInfo.processInfo.environment["FOLIO_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("a04-tour-step4.png"))
        }
    }
}
