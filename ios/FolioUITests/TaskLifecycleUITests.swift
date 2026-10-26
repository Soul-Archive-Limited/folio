import XCTest

/// SPEC §5: "Deleting is the only way an item leaves the calendar. Completing a task never
/// removes it." Drives the real app: tick in To-do, confirm the task is still on its day
/// (shown as done), then delete it and confirm it's gone. XCUITest, as UI automation needs XCTest.
final class TaskLifecycleUITests: XCTestCase {
    private let title = "Water the plants"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnlyDeleteRemovesATaskFromTheCalendar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-FolioResetData", "YES", "-FolioSkipGreeting", "YES", "-FolioSeedTask", title,
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()

        // On today's day panel before anything happens.
        XCTAssertTrue(dayRow(app).waitForExistence(timeout: 5), "task on the calendar")

        // Tick it in To-do and wait past the 1.2 s pause so it moves to Completed.
        app.tabBars.buttons["To-do"].tap()
        let row = todoRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // The checkbox sits at the row's top-leading corner (the row is combined for VoiceOver).
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 22)).tap()
        let completedHeader = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Completed'")).firstMatch
        XCTAssertTrue(completedHeader.waitForExistence(timeout: 4), "moved to Completed")

        // Still on the calendar, marked done.
        app.tabBars.buttons["Calendar"].tap()
        let calendarRow = dayRow(app)
        XCTAssertTrue(calendarRow.waitForExistence(timeout: 5), "completing must not remove it from its day")
        XCTAssertEqual(calendarRow.value as? String, "Done")

        // Delete it from To-do.
        app.tabBars.buttons["To-do"].tap()
        let completedRow = todoRow(app)
        XCTAssertTrue(completedRow.waitForExistence(timeout: 5))
        completedRow.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(completedRow.waitForNonExistence(timeout: 4))

        // Gone from the calendar.
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here yet."].waitForExistence(timeout: 5))
        XCTAssertFalse(dayRow(app).exists, "deleting removes it from the calendar")
    }

    private func todoRow(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "todo-row")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    private func dayRow(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "day-task-row")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }
}
