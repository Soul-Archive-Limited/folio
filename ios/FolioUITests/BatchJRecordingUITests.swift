import XCTest

/// Batch J recordings: search, a scanned page becoming an entry, and the PDF preview, at a
/// watchable pace on the sample diary. Skipped unless `FOLIO_RECORDING` is set.
/// `FOLIO_SCAN_SAMPLE` is the absolute path of a page image for the scan flow.
final class BatchJRecordingUITests: XCTestCase {
    @MainActor
    private func launch(_ extra: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1", "Only for screen recordings")
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES", "-FolioNoTour", "YES",
                               "-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioNow", "2026-10-27T09:30",
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)", "-FolioAPIBase", "http://127.0.0.1:9/api/"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testRecordSearch() throws {
        let app = try launch()
        let search = app.buttons["calendar.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        sleep(1)
        search.press(forDuration: 0.15)
        sleep(1)
        for letter in "river" {
            app.typeText(String(letter))
            usleep(250_000)
        }
        sleep(2)
        let result = app.buttons["search-entry"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        sleep(3)
    }

    @MainActor
    func testRecordScanToEntry() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_RECORDING"] == "1", "Only for screen recordings")
        let sample = try XCTUnwrap(ProcessInfo.processInfo.environment["FOLIO_SCAN_SAMPLE"])
        let app = try launch(["-FolioOpen", "scan", "-FolioScanSample", sample])
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        sleep(3)
        save.press(forDuration: 0.15)
        let show = app.buttons["Show"]
        XCTAssertTrue(show.waitForExistence(timeout: 8))
        sleep(1)
        show.press(forDuration: 0.15)
        sleep(2)
        let card = app.buttons["entry-card"].firstMatch
        if card.waitForExistence(timeout: 5) { card.tap() }
        sleep(3)
    }

    @MainActor
    func testRecordPDFPreview() throws {
        let app = try launch(["-FolioTab", "profile", "-FolioProfilePage", "data"])
        let row = app.buttons["profile.exportPDF"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        sleep(1)
        row.tap()
        let create = app.buttons["pdf.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        sleep(1)
        create.tap()
        XCTAssertTrue(app.buttons["Print"].waitForExistence(timeout: 60))
        sleep(2)
        for _ in 0..<4 {
            app.swipeUp(velocity: .slow)
            usleep(900_000)
        }
        sleep(1)
    }
}
