import XCTest

/// Batch E fix 7: entry cards have swipe actions and a long-press menu. Delete moves the
/// entry to Recently Deleted with an Undo toast (SPEC §5.2), and Undo brings it back.
final class EntryActionsUITests: XCTestCase {
    private let title = "Picnic by the river"

    @MainActor
    private func launch(tab: String = "calendar") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FolioTab", tab, "-FolioToastSeconds", "15", "-hasOnboarded", "YES", "-FolioNoTour", "YES",
                               "-FolioResetData", "YES", "-FolioSkipGreeting", "YES", "-FolioSeedEntry", title,
                               "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()
        return app
    }

    @MainActor
    private func card(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "entry-card")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    @MainActor
    func testSwipeDeleteThenUndo() throws {
        let app = launch()
        let card = card(in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.swipeLeft()
        // A short swipe reveals Delete; a long one runs it straight away.
        let delete = app.buttons["Delete"]
        if delete.waitForExistence(timeout: 2) { delete.tap() }
        XCTAssertTrue(app.staticTexts["Moved to Recently Deleted"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.sheets.firstMatch.exists, "no 'Are you sure?'")
        XCTAssertTrue(card.waitForNonExistence(timeout: 3), "gone from the day panel")
        app.buttons["Undo"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 3), "Undo brings it back")
    }

    @MainActor
    func testSwipeRightOffersEdit() throws {
        let app = launch()
        let card = card(in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.swipeRight()
        let edit = app.buttons["Edit"]
        if edit.waitForExistence(timeout: 2) { edit.tap() }
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 4), "the composer opens on the entry")
        // The title field grows to several lines, so it's a text view.
        let field = app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", title)).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "editing this entry")
    }

    @MainActor
    /// The day cells' own menu still opens (cards and cells share the long press).
    func testDayCellMenuStillOpens() throws {
        let app = launch()
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Thursday 15 October'")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["New task"].waitForExistence(timeout: 3), "control: day menu opens")
    }

    @MainActor
    func testLongPressMenu() throws {
        let app = launch(tab: "journal")  // the Journal timeline; the day panel is covered by the swipe tests
        let card = card(in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.press(forDuration: 1.0)
        for item in ["Edit", "Change date", "Duplicate", "Share", "Delete"] {
            XCTAssertTrue(app.buttons[item].waitForExistence(timeout: 3), "\(item) in the long-press menu")
        }
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Moved to Recently Deleted"].waitForExistence(timeout: 3))
        XCTAssertTrue(card.waitForNonExistence(timeout: 3))
    }
}
