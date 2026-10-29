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
    private let reviewed: XCUIAccessibilityAuditType = [.contrast, .textClipped, .dynamicType, .elementDetection]

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
                let element = issue.element?.label ?? issue.element?.identifier ?? "?"
                let line = "FOLIO_A11Y \(screen.name)\(textSize == nil ? "" : "@AX5") | \(issue.auditType) | \(element) | \(issue.compactDescription)"
                print(line)
                if !self.reviewed.contains(issue.auditType) { findings.append(line) }
                return true
            }
            app.terminate()
        }
        XCTAssertTrue(findings.isEmpty, "\(findings.count) accessibility findings:\n" + findings.joined(separator: "\n"))
    }
}
