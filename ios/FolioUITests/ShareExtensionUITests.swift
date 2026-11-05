import XCTest

/// Batch J: Photos → Share → Folio → Save, then Folio imports it. Runs only when
/// `FOLIO_SHARE_TEST` is set (it drives Photos and needs the sample page in the library:
/// `xcrun simctl addmedia <sim> FolioTests/Resources/sample-diary-page.jpg`).
final class ShareExtensionUITests: XCTestCase {
    @MainActor
    func testShareAPhotoIntoFolio() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_SHARE_TEST"] != nil, "Set FOLIO_SHARE_TEST to run")
        let folio = XCUIApplication()
        folio.launchArguments = ["-hasOnboarded", "YES", "-FolioSkipGreeting", "YES", "-FolioNoTour", "YES",
                                 "-com.apple.TipKit.HideAllTips", "1", "-FolioResetData", "YES"]
        folio.launch()
        sleep(2)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        photos.launch()
        for label in ["Allow", "Continue"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) { button.tap() }
            let inApp = photos.buttons[label]
            if inApp.exists { inApp.tap() }
        }
        // The newest photo is the last cell.
        let cells = photos.images
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 10))
        cells.element(boundBy: cells.count - 1).tap()
        let share = photos.buttons["Share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()

        let folioTarget = photos.collectionViews.cells.matching(NSPredicate(format: "label == 'Folio'")).firstMatch
        if !folioTarget.waitForExistence(timeout: 5) {
            // Not in the first row: More → Folio.
            photos.collectionViews.cells["More"].firstMatch.tap()
            photos.cells.staticTexts["Folio"].firstMatch.tap()
        } else {
            folioTarget.tap()
        }
        let note = photos.textFields["Add a line…"]
        XCTAssertTrue(note.waitForExistence(timeout: 10), "Folio's share composer should appear")
        note.tap()
        note.typeText("Found my old diary")
        if let folder = ProcessInfo.processInfo.environment["FOLIO_SHOTS"] {
            try? photos.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "p6-share-composer.png"))
        }
        photos.buttons["Save"].tap()

        folio.activate()
        let toast = folio.staticTexts["Added 1 shared to Folio"]
        XCTAssertTrue(toast.waitForExistence(timeout: 10))
        XCTAssertTrue(folio.staticTexts["Found my old diary"].waitForExistence(timeout: 5)
                      || folio.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Found my old diary'")).firstMatch.exists)
    }
}
