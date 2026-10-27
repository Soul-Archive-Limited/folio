import XCTest

/// SPEC §6.7 / §6.14: the Undo toast must actually undo. Ticks a task, taps Undo on the toast,
/// and checks the task is back in Active, not done.
final class UndoToastUITests: XCTestCase {
    @MainActor
    func testUndoToastBringsATaskBack() throws {
        let app = XCUIApplication()
        let title = "Fold the laundry"
        app.launchArguments = ["-FolioResetData", "YES", "-FolioSkipGreeting", "YES", "-FolioSeedTask", title,
                               "-FolioTab", "todo", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()

        let row = app.descendants(matching: .any).matching(identifier: "todo-row")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 22)).tap()

        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "toast with Undo appears")
        XCTAssertTrue(undo.isHittable, "Undo must receive touches")
        undo.tap()

        XCTAssertTrue(undo.waitForNonExistence(timeout: 3), "toast closes after Undo")
        XCTAssertEqual(row.value as? String, "Not done")
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Completed'")).firstMatch.exists)
    }
}
