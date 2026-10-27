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

    // MARK: Batch E

    private func entryCard(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "entry-card")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    /// A slow partial drag that reveals a swipe action without running it.
    private func reveal(_ element: XCUIElement, from start: Double, to end: Double) {
        element.coordinate(withNormalizedOffset: CGVector(dx: start, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: element.coordinate(withNormalizedOffset: CGVector(dx: end, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    @MainActor
    func testBatchEFixScreenshots() throws {
        try XCTSkipIf(folder == nil, "Only for batch screenshots")
        let base = ["-FolioNoTour", "YES", "-FolioNow", "2026-10-27T09:30"]

        // 7. Swipe actions and the long-press menu on a day-panel card.
        var app = launch(base + ["-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioSelectDay", "2026-10-25"])
        var card = entryCard(app, "Train to Edinburgh")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Change date"].waitForExistence(timeout: 3))
        shot("07-after-context-menu")
        app.buttons["Edit"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -3)).tap()
        sleep(1)
        reveal(card, from: 0.8, to: 0.55)
        shot("07-after-swipe-delete")
        reveal(card, from: 0.3, to: 0.55)
        reveal(card, from: 0.2, to: 0.45)
        shot("07-after-swipe-edit")
        reveal(card, from: 0.5, to: 0.25)
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Moved to Recently Deleted"].waitForExistence(timeout: 3))
        shot("07-after-delete-toast")

        // 9. Share menu and share sheets on entry detail.
        app = launch(base + ["-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioSelectDay", "2026-10-25", "-FolioOpen", "entry"])
        let share = app.buttons["entry.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.press(forDuration: 0.15)
        XCTAssertTrue(app.buttons["Share as image"].waitForExistence(timeout: 3))
        shot("09-after-share-menu")
        app.buttons["Share as image"].tap()
        sleep(2)
        shot("09-after-share-sheet-image")
        app.terminate()

        app = launch(base + ["-FolioSelectDay", "2026-10-25", "-FolioOpen", "entry"])
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.press(forDuration: 0.15)
        app.buttons["Share text and photos"].tap()
        sleep(2)
        shot("09-after-share-sheet-text-photos")

        // 8. Edit and save an entry, then open it again: no "Continue your draft?".
        app = launch(base + ["-FolioSelectDay", "2026-10-25", "-FolioOpen", "composerLarge"])
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let title = app.descendants(matching: .any).matching(NSPredicate(format: "value == 'Train to Edinburgh'")).firstMatch
        title.tap()
        title.typeText(" again")
        save.press(forDuration: 0.15)
        XCTAssertTrue(app.staticTexts["Entry saved"].waitForExistence(timeout: 4))
        app = launch(base + ["-FolioSelectDay", "2026-10-25", "-FolioOpen", "composerLarge"])
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Continue your draft?"].waitForExistence(timeout: 3), "no draft prompt after saving")
        shot("08-after-reopen-no-prompt")

        // 3. Onboarding: Return continues, and the keyboard doesn't follow.
        app = launch(["-hasOnboarded", "NO", "-FolioOnboardingPage", "3"] + base)
        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Sam")
        shot("03-after-name-typing")
        name.typeText("\n")
        XCTAssertTrue(app.staticTexts["Keep your diary in sync?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        shot("03-after-sync-page-no-keyboard")

        // 4. Tour: the composer step shows only once the sheet has risen.
        app = launch(["-hasOnboarded", "YES", "-FolioSkipGreeting", "YES", "-FolioTourStep", "3", "-FolioNow", "2026-10-27T09:30"])
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.press(forDuration: 0.15)
        XCTAssertTrue(app.staticTexts["Photos, categories, your voice"].waitForExistence(timeout: 5))
        shot("04-after-tour-step4-composer")
    }
}
