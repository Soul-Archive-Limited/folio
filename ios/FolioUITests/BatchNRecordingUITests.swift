import XCTest

/// Batch N recordings: adding a place to a page and the gentle celebrations, at a watchable
/// pace on the sample diary. Skipped unless `FOLIO_RECORDING` is set. Place search needs the
/// network (Apple Maps).
final class BatchNRecordingUITests: XCTestCase {
    @MainActor
    private func launch(_ extra: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1", "Only for screen recordings")
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES", "-FolioNoTour", "YES",
                               "-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioNow", "2026-11-11T09:30",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)", "-FolioAPIBase", "http://127.0.0.1:9/api/"] + extra
        app.launch()
        return app
    }

    /// Composer → Place → search "Tate Modern" → pick → Save → the page with its map.
    @MainActor
    func testRecordPlaceFlow() throws {
        let app = try launch(["-FolioSelectDay", "2026-11-12", "-FolioOpen", "composer"])
        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        sleep(1)
        title.tap()
        for letter in "Afternoon at the Tate" { app.typeText(String(letter)); usleep(60_000) }
        sleep(1)
        app.buttons["composer.place"].press(forDuration: 0.15)
        let field = app.searchFields["Search places"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        for letter in "Tate Modern" { app.typeText(String(letter)); usleep(150_000) }
        let result = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tate Modern'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20))
        sleep(1)
        result.tap()
        sleep(2)
        app.buttons["Save"].press(forDuration: 0.15)
        sleep(2)
        let card = app.buttons["entry-card"].firstMatch
        if card.waitForExistence(timeout: 5) { card.tap() }
        sleep(4)
    }
}
