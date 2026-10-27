import XCTest

/// SPEC §5.2 end to end: Delete moves a task to Recently Deleted without asking, the toast
/// says so, the quiet link at the end of To-do opens Recently Deleted, and Restore brings the
/// task back with a "Restored to …" toast whose Show jumps to the calendar day.
/// With `FOLIO_RECORDING=1` it pauses between steps for the screen recording.
final class RecentlyDeletedUITests: XCTestCase {
    private var paced: Bool { ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1" }

    private func pause() {
        if paced { sleep(1) }
    }

    @MainActor
    func testDeleteThenRestoreFromRecentlyDeleted() throws {
        let app = XCUIApplication()
        let title = "Water the plants"
        app.launchArguments = ["-FolioToastSeconds", "15", "-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1",
                               "-FolioResetData", "YES", "-FolioSkipGreeting", "YES", "-FolioSeedTask", title,
                               "-FolioTab", "todo", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()

        let row = app.descendants(matching: .any).matching(identifier: "todo-row")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        pause()
        row.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()

        XCTAssertFalse(app.sheets.firstMatch.waitForExistence(timeout: 1), "no 'Are you sure?'")
        XCTAssertTrue(app.staticTexts["Moved to Recently Deleted"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Undo"].exists)
        XCTAssertTrue(row.waitForNonExistence(timeout: 3), "gone from To-do")
        pause()

        let link = app.buttons["recently-deleted-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 3), "quiet link at the end of To-do")
        link.tap()
        XCTAssertTrue(app.navigationBars["Recently Deleted"].waitForExistence(timeout: 3))
        app.buttons["Tasks"].tap()
        let trashRow = app.descendants(matching: .any).matching(identifier: "trash-row")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(trashRow.waitForExistence(timeout: 3))
        XCTAssertTrue(trashRow.label.contains("30 days left"), trashRow.label)
        pause()

        trashRow.swipeRight()
        let restore = app.buttons["Restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 3))
        restore.tap()

        let restored = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Restored to '")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 3), "restore toast")
        XCTAssertTrue(app.staticTexts["Nothing here. Deleted items stay for 30 days."].waitForExistence(timeout: 3))
        pause()
        let show = app.buttons["Show"]
        XCTAssertTrue(show.exists)
        show.tap()

        // Show jumps to the task's day on the calendar, where it's back.
        let dayRow = app.descendants(matching: .any).matching(identifier: "day-task-row")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(dayRow.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Calendar"].isSelected)
        pause()
    }
}
