import XCTest

/// Batch M: where the law requires Apple's age check, ticking "I'm 18 or older" asks Apple
/// first (simulated with `-FolioAgeCheck`, since the Simulator has no age range to share).
final class AgeCheckUITests: XCTestCase {
    private static let consentLabel = "I’m 18 or older and agree to the Terms and Privacy Policy"

    @MainActor
    private func launch(answer: String) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-FolioResetAccount", "YES", "-FolioSkipGreeting", "YES", "-FolioNoTour", "YES",
                               "-FolioTab", "profile", "-FolioProfilePage", "account", "-FolioAgeCheck", answer, "-FolioToastSeconds", "15"]
        app.launch()
        let consent = app.descendants(matching: .any)[Self.consentLabel].firstMatch
        XCTAssertTrue(consent.waitForExistence(timeout: 20))
        // Bring the box up from behind the tab bar, so the message under it is in view too: a
        // held drag, which stops where it ends (a swipe's momentum carried the box off screen).
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        from.press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(consent.isHittable)
        return (app, consent)
    }

    @MainActor
    func testUnder18CantTickTheBox() {
        let (app, consent) = launch(answer: "minor")
        consent.tap()
        let problem = app.staticTexts["ageProblem"]
        XCTAssertTrue(problem.waitForExistence(timeout: 10))
        XCTAssertTrue(problem.label.contains("Folio accounts are for adults"))
        XCTAssertNotEqual(consent.value as? String, "1", "the box stays unticked")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "age-check-minor-\(UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light")"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testNoAnswerFromAppleAsksToTryAgain() {
        let (app, consent) = launch(answer: "network")
        consent.tap()
        XCTAssertTrue(app.staticTexts["ageProblem"].waitForExistence(timeout: 10))
        XCTAssertNotEqual(consent.value as? String, "1")
    }

    @MainActor
    func testAdultTicksTheBox() {
        let (app, consent) = launch(answer: "adult")
        consent.tap()
        let ticked = NSPredicate(format: "value == '1'")
        expectation(for: ticked, evaluatedWith: consent)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.staticTexts["ageProblem"].exists)
    }
}
