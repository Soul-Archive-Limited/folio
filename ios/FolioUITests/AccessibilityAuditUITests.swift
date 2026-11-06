import XCTest

/// Phase 14: Accessibility Inspector's audit (`performAccessibilityAudit`) on every main
/// screen, at the default text size and at AX5. Skipped unless `FOLIO_A11Y_AUDIT` is set
/// (`TEST_RUNNER_FOLIO_A11Y_AUDIT=1 xcodebuild test …`); it takes several minutes.
/// Every finding is printed as `FOLIO_A11Y <screen> | <type> | <element> | <description>`.
/// Hit areas, labels, traits and other kinds fail the test; the kinds in `reviewed`
/// are only printed, because on Liquid Glass they were false positives when checked by hand
/// (DECISIONS 211): re-check new ones in screenshots.
final class AccessibilityAuditUITests: XCTestCase {
    private struct Screen {
        let name: String
        let args: [String]
    }

    private let screens: [Screen] = [
        Screen(name: "calendar", args: []),
        Screen(name: "privacy-cover", args: ["-FolioScreen", "cover"]),
        Screen(name: "calendar-collapsed", args: ["-FolioCollapsed", "YES"]),
        Screen(name: "jump", args: ["-FolioJumpSheet", "YES"]),
        Screen(name: "composer", args: ["-FolioOpen", "composer"]),
        Screen(name: "entry", args: ["-FolioOpen", "entry"]),
        Screen(name: "task-composer", args: ["-FolioOpen", "taskComposer"]),
        Screen(name: "journal", args: ["-FolioTab", "journal"]),
        Screen(name: "journal-photos", args: ["-FolioTab", "journal", "-FolioJournalMode", "photos"]),
        // Batch L: Year in Pixels, search, and the sign-in card with the 18+ box (Profile, guest).
        Screen(name: "journal-year", args: ["-FolioTab", "journal", "-FolioJournalMode", "year"]),
        Screen(name: "search", args: ["-FolioTab", "journal", "-FolioSearch", "river"]),
        Screen(name: "todo", args: ["-FolioTab", "todo"]),
        Screen(name: "profile", args: ["-FolioTab", "profile"]),
        Screen(name: "categories", args: ["-FolioTab", "profile", "-FolioOpen", "categories"]),
        Screen(name: "recently-deleted", args: ["-FolioTab", "profile", "-FolioOpen", "recentlyDeleted", "-FolioTrashSamples", "YES"]),
    ]

    /// Printed, not failed (DECISIONS 211): contrast is sampled through glass and measured
    /// 5.5–17:1 in screenshots; "clipped" text wasn't clipped on screen (scroll-edge masks and
    /// intentional one/two-line previews); Dynamic Type limits are the system toolbar and date
    /// picker's; element detection flags the weekday initials and the year beside the month,
    /// hidden on purpose because each day cell and the month button speak the full date.
    private let reviewed: XCUIAccessibilityAuditType = [.contrast, .textClipped, .dynamicType, .elementDetection, XCUIAccessibilityAuditType(rawValue: 65536)]

    /// iOS 26's "Dynamic Type font sizes are partially unsupported" (raw 65536), reported only for
    /// system toolbar items and the compact navigation title, whose sizes the system caps (Batch L).

    /// Year in Pixels draws 365 days on a phone, so each square is smaller than 44 pt by design;
    /// every page it opens is also reachable from the Calendar and Journal with full-size targets
    /// (WCAG 2.5.8's "equivalent" exception; Batch L).
    private func isAccepted(_ issue: XCUIAccessibilityAuditIssue, on screen: String) -> Bool {
        guard issue.auditType == .hitRegion else { return false }
        // The search field's own clear (×) button is the system's.
        return screen.hasPrefix("journal-year") || issue.element?.label == "Clear text"
    }

    /// Diagnostics (Batch L): every hittable element under 44 pt on the calendar, with its type.
    @MainActor
    func testListSmallTargets() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES", "-FolioSkipGreeting", "YES", "-com.apple.TipKit.HideAllTips", "1",
                               "-FolioResetData", "YES", "-FolioSampleData", "YES", "-FolioNow", "2026-10-27T09:30", "-FolioSelectDay", "2026-10-22"]
        app.launch()
        sleep(3)
        for element in app.descendants(matching: .any).allElementsBoundByIndex where element.isHittable {
            let f = element.frame
            if f.width < 44 || f.height < 44 {
                print("FOLIO_SMALL type=\(element.elementType.rawValue) label=\(element.label) id=\(element.identifier) frame=\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))")
            }
        }
    }

    @MainActor
    func testAuditDefaultTextSize() throws {
        try audit(textSize: nil)
    }

    @MainActor
    func testAuditAX5() throws {
        try audit(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    @MainActor
    private func audit(textSize: String?) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOLIO_A11Y_AUDIT"] == "1", "Slow; run on demand")
        var findings: [String] = []
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = ["-hasOnboarded", "YES", "-com.apple.TipKit.HideAllTips", "1", "-FolioSkipGreeting", "YES",
                                   "-FolioNoTour", "YES", "-FolioResetData", "YES", "-FolioSampleData", "YES",
                                   // The audit makes the app briefly inactive, which raises the privacy
                                   // cover over the screen being audited; the cover has its own entry.
                                   "-privacyCoverEnabled", "NO",
                                   "-FolioNow", "2026-10-27T09:30", "-FolioSelectDay", "2026-10-22",
                                   "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"] + screen.args
            if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
            app.launch()
            sleep(3)
            try app.performAccessibilityAudit { issue in
                let element = (issue.element?.label).flatMap { $0.isEmpty ? nil : $0 } ?? issue.element?.identifier
                    ?? issue.element.map { "type \($0.elementType.rawValue) at \(Int($0.frame.minX)),\(Int($0.frame.minY)) \(Int($0.frame.width))×\(Int($0.frame.height))" } ?? "?"
                let line = "FOLIO_A11Y \(screen.name)\(textSize == nil ? "" : "@AX5") | \(issue.auditType) | \(element) | \(issue.compactDescription)"
                print(line)
                if !self.reviewed.contains(issue.auditType) && !self.isAccepted(issue, on: screen.name) { findings.append(line) }
                return true
            }
            app.terminate()
        }
        XCTAssertTrue(findings.isEmpty, "\(findings.count) accessibility findings:\n" + findings.joined(separator: "\n"))
    }
}
