import XCTest

/// Takes the Recently Deleted screenshots for batch reports. Skipped unless run with
/// `TEST_RUNNER_FOLIO_SHOTS=<absolute folder>`; PNGs are written there (Simulator only).
final class ScreenshotUITests: XCTestCase {
    private var folder: String? { ProcessInfo.processInfo.environment["FOLIO_SHOTS"] }

    private func shot(_ name: String) {
        guard let folder else { return }
        sleep(1)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES",
                               "-FolioToastSeconds", "20", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"] + extra
        app.launch()
        return app
    }

    private func trashRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "trash-row")
    }

    @MainActor
    func testRecentlyDeletedScreenshots() throws {
        try XCTSkipIf(folder == nil, "Only for batch screenshots")

        // Empty state.
        var app = launch(["-FolioResetData", "YES", "-FolioTab", "profile", "-FolioOpen", "recentlyDeleted"])
        XCTAssertTrue(app.staticTexts["Nothing here. Deleted items stay for 30 days."].waitForExistence(timeout: 8))
        shot("10-recently-deleted-empty")

        // Delete toast on To-do.
        app = launch(["-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioTab", "todo"])
        let task = app.descendants(matching: .any).matching(identifier: "todo-row")
            .matching(NSPredicate(format: "label CONTAINS 'Call Mum'")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Moved to Recently Deleted"].waitForExistence(timeout: 3))
        shot("11-delete-toast")

        // List, preview, swipe actions, select mode, restore toast.
        app = launch(["-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioTrashSamples", "YES",
                      "-FolioTab", "profile", "-FolioOpen", "recentlyDeleted"])
        XCTAssertTrue(trashRows(app).firstMatch.waitForExistence(timeout: 8))
        app.buttons["Tasks"].tap()
        shot("08-recently-deleted-tasks")
        app.buttons["Entries"].tap()
        trashRows(app).firstMatch.tap()
        XCTAssertTrue(app.buttons["Delete now"].waitForExistence(timeout: 3))
        shot("07-recently-deleted-preview")
        app.buttons["Close"].tap()

        let row = trashRows(app).element(boundBy: 1)
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.swipeRight()
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 3))
        shot("09-swipe-restore")
        app.buttons["Entries"].tap() // closes the swipe
        row.swipeLeft()
        XCTAssertTrue(app.buttons["Delete now"].waitForExistence(timeout: 3))
        shot("09b-swipe-delete-now")
        app.buttons["Entries"].tap()

        app.buttons["Select"].tap()
        trashRows(app).firstMatch.tap()
        shot("09c-select-mode")
        app.buttons["Done"].tap()

        row.swipeRight()
        app.buttons["Restore"].tap()
        let restored = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Restored to '")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 3))
        shot("12-restore-toast")
    }
}
