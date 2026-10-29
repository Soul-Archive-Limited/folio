import XCTest

/// Phase 13 before/after recordings: drives each moment at a watchable pace on the sample
/// diary. Skipped unless `FOLIO_RECORDING` is set: `TEST_RUNNER_FOLIO_RECORDING=1 xcodebuild test …`.
final class MotionRecordingUITests: XCTestCase {
    private func launch(_ extra: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1", "Only for screen recordings")
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES",
                               "-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioNow", "2026-10-27T09:30",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"] + extra
        app.launch()
        return app
    }

    private func day(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    @MainActor
    func testRecordDayTaps() throws {
        let app = try launch()
        XCTAssertTrue(day(app, "Wednesday 21 October").waitForExistence(timeout: 8))
        sleep(1)
        for label in ["Wednesday 21 October", "Tuesday 13 October", "Tuesday 6 October", "Tuesday 27 October"] {
            day(app, label).tap()
            usleep(1_200_000)
        }
    }

    @MainActor
    func testRecordCalendarFilter() throws {
        let app = try launch()
        let filter = app.buttons["Filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 8))
        sleep(1)
        filter.tap()
        app.buttons["Travel"].tap()
        sleep(2)
        app.buttons["Filter, on"].tap()
        app.buttons["All categories"].tap()
        sleep(2)
    }

    @MainActor
    func testRecordJournalFilter() throws {
        let app = try launch(["-FolioTab", "journal"])
        let travel = app.buttons["Travel"]
        XCTAssertTrue(travel.waitForExistence(timeout: 8))
        sleep(1)
        travel.press(forDuration: 0.3)
        sleep(2)
        app.buttons["All"].press(forDuration: 0.3)
        sleep(2)
    }

    /// iPad: page through months in the calendar column.
    @MainActor
    func testRecordMonthPaging() throws {
        let app = try launch()
        let grid = day(app, "Wednesday 21 October")
        XCTAssertTrue(grid.waitForExistence(timeout: 8))
        sleep(1)
        grid.swipeLeft()
        sleep(1)
        day(app, "Saturday 21 November").swipeRight()
        sleep(1)
        day(app, "Wednesday 21 October").swipeRight()
        sleep(2)
    }
}

/// Phase 13 Instruments runs (Animation Hitches, Time Profiler): the main flows on the
/// 10,000-entry DEBUG diary. Skipped unless `FOLIO_PERF` is set.
final class MotionPerfUITests: XCTestCase {
    @MainActor
    func testPerfMainFlows() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_PERF"] == "1", "Only for Instruments runs")
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES",
                               "-FolioResetData", "YES", "-FolioStressData", "YES", "-FolioNoTour", "YES", "-FolioHitchLog", "YES",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()
        let newEntry = app.buttons["New entry"]
        XCTAssertTrue(newEntry.waitForExistence(timeout: 60))
        sleep(2)

        // Page months (drag across the grid's middle row).
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.32))
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.32))
        mark(app, "paging")
        for _ in 0..<6 { right.press(forDuration: 0.01, thenDragTo: left, withVelocity: .fast, thenHoldForDuration: 0); usleep(600_000) }
        for _ in 0..<6 { left.press(forDuration: 0.01, thenDragTo: right, withVelocity: .fast, thenHoldForDuration: 0); usleep(600_000) }

        // Open and close the composer.
        mark(app, "composer")
        for _ in 0..<3 {
            newEntry.tap()
            let cancel = app.buttons["Cancel"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 5))
            sleep(1)
            cancel.tap()
            sleep(1)
        }

        // Scroll the Journal.
        mark(app, "journal")
        app.buttons["Journal"].firstMatch.tap()
        sleep(2)
        for _ in 0..<8 { app.swipeUp(velocity: .fast) }
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
        sleep(1)
        mark(app, "end")
    }

    /// Prints the wall-clock time so the hitch log's seconds can be split by flow.
    private func mark(_ app: XCUIApplication, _ name: String) {
        print("FOLIO_PERF_MARK \(name) \(Date().timeIntervalSince1970)")
    }
}
