import XCTest

/// Two-Simulator sync steps against the live API (Phase 10). Each test is one step on one
/// Simulator; `scripts/sync-live-test.sh` runs them in order on two devices. Skipped unless
/// `TEST_RUNNER_FOLIO_REVIEW_CODE` is set (App Review sign-in for review@devilsense.com).
/// Screenshots go to `TEST_RUNNER_FOLIO_SHOTS` when set.
final class SyncLiveUITests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var code: String? { env["FOLIO_REVIEW_CODE"] }
    static let email = "review@devilsense.com"

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Steps

    /// A: a guest diary (sample data) signs in to a new account, saves the recovery key
    /// (copied to the Simulator's pasteboard for the host), and uploads everything.
    @MainActor func testA1SignInNewAccount() throws {
        let app = try launch(["-FolioResetAccount", "YES", "-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioTab", "profile"])
        shot("p10-01-profile-guest")
        try signIn(app)
        let key = app.staticTexts["recoveryKey"]
        XCTAssertTrue(key.waitForExistence(timeout: 30))
        shot("p10-04-recovery-key")
        let characters = key.label.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        XCTAssertEqual(characters.count, 26)
        app.buttons["Copy"].tap()
        let confirm = app.textFields["recoveryConfirm"]
        confirm.tap()
        confirm.typeText(String(characters.suffix(4)))
        shot("p10-05-recovery-confirmed")
        app.buttons["Continue"].firstMatch.tap()
        sleep(2)
        shot("p10-06-first-sync-progress")
        try waitForAllSet(app, timeout: 300)
        shot("p10-07-all-set")
        app.buttons["Done"].tap()
        try scrollTo(app.buttons["syncNow"], in: app)
        shot("p10-08-profile-signed-in")
    }

    /// B: a fresh device signs in to the same account and shows the link QR; its text goes to
    /// the pasteboard (no camera in the Simulator). Waits until A approves, then syncs.
    @MainActor func testB1SignInAndWaitForQR() throws {
        let app = try launch(["-FolioResetAccount", "YES", "-FolioResetData", "YES", "-FolioTab", "profile"])
        try signIn(app)
        let scan = app.buttons["Scan from your other device"]
        XCTAssertTrue(scan.waitForExistence(timeout: 30))
        shot("p10-09-unlock-choices")
        scan.tap()
        let copy = app.buttons["copyLinkText"]
        XCTAssertTrue(copy.waitForExistence(timeout: 30))
        shot("p10-10-unlock-qr")
        copy.tap()
        try waitForAllSet(app, timeout: 300)
        shot("p10-13-b-unlocked-synced")
        app.buttons["Done"].tap()
    }

    /// B, already signed in but locked: Profile → Unlock your diary → show a new QR.
    @MainActor func testB1bUnlockFromProfile() throws {
        let app = try launch(["-FolioTab", "profile"])
        let unlock = app.buttons["Unlock your diary"]
        try scrollTo(unlock, in: app)
        shot("p10-09b-profile-locked")
        unlock.tap()
        let scan = app.buttons["Scan from your other device"]
        XCTAssertTrue(scan.waitForExistence(timeout: 20))
        shot("p10-09-unlock-choices")
        scan.tap()
        let copy = app.buttons["copyLinkText"]
        XCTAssertTrue(copy.waitForExistence(timeout: 30))
        shot("p10-10-unlock-qr")
        copy.tap()
        try waitForAllSet(app, timeout: 300)
        shot("p10-13-b-unlocked-synced")
        app.buttons["Done"].tap()
    }

    /// A: Profile → Link a browser or device → paste B's code → Allow (Face ID is matched by
    /// the host script through the Simulator's biometric notifications).
    @MainActor func testA2ApproveLink() throws {
        let text = try XCTUnwrap(env["FOLIO_LINK_TEXT"])
        let app = try launch(["-FolioTab", "profile"])
        let link = app.buttons["linkDevice"]
        try scrollTo(link, in: app)
        link.tap()
        let field = app.textFields["linkPaste"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        shot("p10-11-link-scanner")
        field.tap()
        field.typeText(text)
        app.buttons["linkPasteUse"].tap()
        let allow = app.buttons["linkAllow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 20))
        shot("p10-12-link-approve")
        allow.tap()
        XCTAssertTrue(app.staticTexts["Linked"].waitForExistence(timeout: 20))
    }

    /// Either device: launch (optionally with an edit from DebugLaunchOptions) and stay in the
    /// foreground long enough to push.
    @MainActor func testEditAndStay() throws {
        let extra = (env["FOLIO_EXTRA_ARGS"] ?? "").split(separator: "|").map(String.init)
        let app = try launch(["-FolioTab", "journal"] + extra)
        print("SYNCTIME edit-launched \(Date().timeIntervalSince1970)")
        sleep(UInt32(env["FOLIO_STAY_SECONDS"].flatMap(UInt32.init) ?? 8))
        if let name = env["FOLIO_SHOT"] { shot(name) }
        _ = app
    }

    /// Wait in the foreground until an entry with this title appears (or disappears).
    @MainActor func testWaitForEntry() throws {
        let title = try XCTUnwrap(env["FOLIO_TITLE"])
        let gone = env["FOLIO_EXPECT_GONE"] == "1"
        let app = try launch(["-FolioTab", "journal"])
        let card = app.descendants(matching: .any).matching(identifier: "entry-card")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        let start = Date()
        let predicate = NSPredicate(format: gone ? "exists == false" : "exists == true")
        let result = XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: card)], timeout: 90)
        print("SYNCTIME seen \(Date().timeIntervalSince1970) after \(Date().timeIntervalSince(start)) s")
        XCTAssertEqual(result, .completed, "Entry \(title) never \(gone ? "left" : "arrived")")
        if let name = env["FOLIO_SHOT"] { sleep(1); shot(name) }
        sleep(UInt32(env["FOLIO_STAY_SECONDS"].flatMap(UInt32.init) ?? 0))
    }

    /// Profile with the sync status row on screen (for the status screenshots).
    @MainActor func testShowSyncStatus() throws {
        let extra = (env["FOLIO_EXTRA_ARGS"] ?? "").split(separator: "|").map(String.init)
        let app = try launch(["-FolioTab", "profile"] + extra)
        try scrollTo(app.buttons["syncStatus"], in: app)
        sleep(UInt32(env["FOLIO_STAY_SECONDS"].flatMap(UInt32.init) ?? 6))
        shot(env["FOLIO_SHOT"] ?? "p10-sync-status")
        if let expected = env["FOLIO_EXPECT_STATUS"] {
            XCTAssertTrue(app.buttons["syncStatus"].label.contains(expected), app.buttons["syncStatus"].label)
        }
    }

    /// Recently Deleted on this device (after another device trashed an entry).
    @MainActor func testShowRecentlyDeleted() throws {
        let title = try XCTUnwrap(env["FOLIO_TITLE"])
        let app = try launch(["-FolioTab", "profile", "-FolioOpen", "recentlyDeleted"])
        let row = app.descendants(matching: .any).matching(identifier: "trash-row")
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 60))
        shot("p10-17-b-recently-deleted")
    }

    /// A: Profile → Recovery key → Copy (no passcode on the test Simulator, so no prompt).
    @MainActor func testCopyRecoveryKey() throws {
        let app = try launch(["-FolioTab", "profile"])
        let row = app.buttons["Recovery key"]
        try scrollTo(row, in: app)
        row.tap()
        XCTAssertTrue(app.staticTexts["recoveryKey"].waitForExistence(timeout: 10))
        shot("p10-15-show-recovery-key")
        app.buttons["Copy"].tap()
    }

    /// B: a fresh device that unlocks with the recovery key instead of a QR.
    @MainActor func testB2RecoveryKeyUnlock() throws {
        let recovery = try XCTUnwrap(env["FOLIO_RECOVERY"])
        let app = try launch(["-FolioResetAccount", "YES", "-FolioResetData", "YES", "-FolioTab", "profile"])
        try signIn(app)
        let enter = app.buttons["Enter recovery key"]
        XCTAssertTrue(enter.waitForExistence(timeout: 30))
        enter.tap()
        // A multi-line TextField is a text view to XCUITest.
        let field = app.descendants(matching: .any).matching(identifier: "recoveryEntry").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(recovery)
        shot("p10-18-recovery-entry")
        app.buttons["Unlock"].tap()
        try waitForAllSet(app, timeout: 300)
        app.buttons["Done"].tap()
    }

    /// Devices list, then delete the account — re-authenticating with an email code — keeping
    /// this iPhone's copy.
    @MainActor func testDeleteAccount() throws {
        let app = try launch(["-FolioTab", "profile"])
        let devices = app.buttons["Devices"]
        try scrollTo(devices, in: app)
        devices.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'this device'")).firstMatch.waitForExistence(timeout: 20))
        shot("p10-19-devices")
        app.navigationBars.buttons["BackButton"].tap()
        let delete = app.buttons["Delete account"]
        try scrollTo(delete, in: app)
        delete.tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        shot("p10-20-delete-explain")
        app.buttons["Continue"].tap()
        // After a relaunch the app doesn't know the sign-in is fresh: confirm with a code.
        if app.buttons["Continue with email"].waitForExistence(timeout: 3) {
            shot("p10-20b-delete-reauth")
            app.buttons["Continue with email"].tap()
            app.buttons["Send code"].tap()
            let codeField = app.textFields["Six-digit code"]
            XCTAssertTrue(codeField.waitForExistence(timeout: 20))
            codeField.typeText(try XCTUnwrap(code))
        }
        let confirm = app.textFields["deleteConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        if !app.keyboards.firstMatch.waitForExistence(timeout: 5) { confirm.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        confirm.typeText("DELETE")
        shot("p10-21-delete-confirm")
        app.buttons["deleteKeep"].tap()
        let guest = app.staticTexts["Sync & web access"]
        try scrollTo(guest, in: app, timeout: 30)
        shot("p10-22-after-delete-guest")
    }

    // MARK: Helpers

    @MainActor private func launch(_ extra: [String]) throws -> XCUIApplication {
        try XCTSkipIf(code == nil, "Live sync test: needs TEST_RUNNER_FOLIO_REVIEW_CODE")
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES",
                               "-FolioNoTour", "YES", "-FolioToastSeconds", "20", "-AppleLocale", "en_GB",
                               "-AppleLanguages", "(en-GB)", "-FolioSkipOwnerAuth", "YES"] + extra
        app.launch()
        return app
    }

    @MainActor private func signIn(_ app: XCUIApplication) throws {
        let emailButton = app.buttons["Continue with email"]
        try scrollTo(emailButton, in: app)
        emailButton.tap()
        let field = app.textFields["Email address"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText(Self.email)
        shot("p10-02-email")
        app.buttons["Send code"].tap()
        let codeField = app.textFields["Six-digit code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 20))
        shot("p10-03-email-code")
        codeField.typeText(try XCTUnwrap(code))
    }

    @MainActor private func waitForAllSet(_ app: XCUIApplication, timeout: TimeInterval) throws {
        let done = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'all set'")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: timeout), "First sync didn't finish")
    }

    @MainActor private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 10) throws {
        _ = element.waitForExistence(timeout: timeout)
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 12 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        // Let the list stop coasting, or the tap lands on whatever row slides under it.
        if swipes > 0 { sleep(2) }
        XCTAssertTrue(element.isHittable, "\(element) not reachable")
    }

    @MainActor private func shot(_ name: String) {
        guard let folder = env["FOLIO_SHOTS"] else { return }
        sleep(1)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
    }
}
