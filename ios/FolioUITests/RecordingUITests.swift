import XCTest

/// Drives the tick → move → Undo flow at a watchable pace for the Batch B screen recording.
/// Skipped unless `FOLIO_RECORDING` is set: `TEST_RUNNER_FOLIO_RECORDING=1 xcodebuild test …`.
final class RecordingUITests: XCTestCase {
    @MainActor
    func testRecordTickMoveUndo() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1", "Only for screen recordings")
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES", "-FolioTab", "todo", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()

        let row = app.descendants(matching: .any).matching(identifier: "todo-row")
            .matching(NSPredicate(format: "label CONTAINS 'Post the letter'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        sleep(1)
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 22)).tap()
        sleep(2) // ticked, then moves to Completed after 1.2 s
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()
        sleep(2)
        XCTAssertEqual(row.value as? String, "Not done")
    }
}
