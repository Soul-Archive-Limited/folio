# Batch G report

Batch G = your test of 0.1.0 (49) (Part 1) · Phase 13 motion & performance (Part 2) · Phase 14 compliance, App Review readiness and TestFlight for friends (Part 3). Shape per SPEC §18, one section per part. Contact sheet: `docs/screenshots/batch-g/00-contact-sheet.png`.

---

## Part 1 — Your test of 0.1.0 (49) + the web app

**Built:** nothing. You hadn't tested yet; your notes go into the next batch. The Apple web sign-in setting (Services ID domain + return URL) is confirmed on your side; signing in with Apple in a browser is still untested.
**Next phase ready:** yes.

## Part 2 — Phase 13: motion & performance

PHASE 13 REPORT

**Built:**
- **iPad (SPEC §6.16):** the tabs become a sidebar; Calendar is a resizable split — month column (360–760 pt) · day panel and entry detail. The grid fits the column's width and height. Before this, iPad showed two half months side by side (the month pager kept its iPhone-width offset); the pagers now rebuild at the visible month when their width changes.
- **Motion fixes (iOS):** category filters animate the lists they filter; the calendar filter fades markers instead of snapping; the day title cross-fades while only the rows re-enter (it used to pop); sync status and guest ↔ signed-in animate; every curve comes from `FolioMotion`, and Reduce Motion is honoured by models too (To-do's 1.2 s move, Recently Deleted, photo strip).
- **Performance (10,000 entries, Simulator):** the Journal no longer fetches every entry on each redraw just to check whether it's empty; month grouping is cheaper; day-cell VoiceOver labels are cached; the composer stopped making a synchronous call to Apple's model on every redraw. Worst frame: Journal tab switch 444 → ~200–270 ms; month paging ~70–80 ms (one late frame per page, unchanged); composer cold open ~180–220 ms, warm 47–70 ms; Journal scrolling 0 late frames before and after.
- **Web:** hover effects only for mouse/trackpad (no sticky hover on phones), no grey tap flash or tap delay, Reduce Motion now cross-fades instead of cutting, and the composer/Journal/To-do code preloads when the browser is idle — first "New entry" 158 → 9 ms. CLS 0.0000 on every flow, no frame over 17 ms.
- **Tools kept for later:** DEBUG-only `HitchMonitor` (`-FolioHitchLog YES`) and `PerfDriver` (`-FolioPerfScript YES`), `MotionRecordingUITests` / `MotionPerfUITests` (skipped unless `FOLIO_RECORDING` / `FOLIO_PERF`).

**Files changed:** 35 (commit e999eba): `ios/Folio/Features/Calendar/CalendarSplitView.swift` (new), `CalendarScreen`, `CalendarGridArea`, `DayPanel`, `DayCell`, `DayCellAccessibility`, `JournalModel`/`JournalScreen`, `DiaryStore`, `WritingAssistant`, `FolioMotion`, `MainTabView`, `web/src/app/app.css`, `web/src/app/ui/{Shell,common}.tsx`.

**Screenshots / recordings** (`docs/screenshots/batch-g/`; each clip is before on the left, after on the right, under 300 KB):
- `p2-01-ipad-calendar-before.png` — two half months on iPad
- `p2-01-ipad-calendar-after.png` / `-dark.png` — sidebar · month · day panel
- `p2-02-ipad-entry-detail-dark.png` — entry detail beside the month
- `p2-03-web-composer.png` — web composer as a right-side sheet
- `rec-01-month-paging-…mp4` — iPad month paging: broken → split view
- `rec-02-day-taps-…mp4` — day title cross-fades instead of popping
- `rec-03-calendar-filter-…mp4` — filter fades markers instead of snapping
- `rec-04-journal-filter-…mp4` — Journal rows move with the filter instead of jumping
- `rec-05-web-composer-reduced-motion-…mp4` — web composer with Reduce Motion: hard cut → fade

**Tests:** iOS 162 app + 19 crypto unit tests pass; all UI tests pass locally (CI's iOS run on e999eba hit one UI-query timeout in `UndoToastUITests` on the slow runner; the next run passed). Web: typecheck, 35 unit tests, 15 build checks pass.

**Security:** gitleaks clean on every commit.

**Deviations from SPEC:**
1. Instruments' Animation Hitches can't run on the Simulator and your iPhone wasn't connected, so hitches were measured with Time Profiler plus a DEBUG frame monitor on the Simulator (pessimistic numbers). The 120 fps / "no hitch over one frame" target is **not verified on a device**.
2. No collapse-to-week on iPad: the day panel has its own column.

**Manual steps needed from the owner:** none for this part.
**Known issues:**
1. Composer cold open ~200 ms and month paging ~70 ms on the Simulator; needs a device run to know the real numbers.
2. At AX5 the calendar's list layout scrolls under the status bar without a fade.

**Next phase ready:** yes.

## Part 3 — Phase 14: compliance, App Review readiness, TestFlight for friends

PHASE 14 REPORT

**Built:**
- **SPEC §12 and §13 line by line** — ticked in `docs/PHASES.md` with evidence. Added the "© 2026 Soul Archive Ltd" line in Profile → About.
- **Privacy:** `PrivacyInfo.xcprivacy` final (no tracking; Email Address, Photos or Videos, Other User Content, User ID, Other Data; UserDefaults `CA92.1` only — one boot-time API swapped for `ContinuousClock` so no unverifiable reason code is needed). I first proposed not declaring the end-to-end-encrypted diary (Apple's "collect" means data you can access; DECISIONS 209); you chose to declare it anyway, as Day One and Ente do, so the label, manifest and privacy policy now list photos and other diary content (DECISIONS 212). The server no longer keeps raw IP addresses in rate-limit rows (keyed hash; API deployed with your OK, version 0cd68092). Privacy policy updated (device model, hashed addresses).
- **Accessibility:** Accessibility Inspector's audit on 13 screens at default size and AX5. First run had 176 findings. Fixed: grey caption text below AA (now 5.5:1 measured), three controls with under-44 pt hit areas, fixed-size sign-in text, and the privacy cover sitting invisibly in the accessibility tree. The rest were checked by hand and are false positives on Liquid Glass (DECISIONS 211). Reduce Motion, Reduce Transparency, Increase Contrast and AX5 checked.
- **Final /vibesec** across api, web and iOS: one fix (raw IPs, above); no other findings. gitleaks: all 53 commits clean. `npm audit`: 0 vulnerabilities.
- **`docs/APPSTORE.md`:** name, subtitle, description, keywords, promo text, categories, URLs, privacy label answers, export compliance, age rating answers (→ 4+), EU trader note, App Review notes, TestFlight Test Information, and the list of what's still needed for a public release.
- **App Store screenshots** (`docs/appstore/`, JPEG, no alpha, sample data): 7 iPhone 6.3" (1206 × 2622) and 4 iPad 13" landscape (2752 × 2064).
- **TestFlight:** 0.1.0 (54) uploaded first; after the owner's privacy-label decision (DECISIONS 212) **0.1.0 (56)** was archived and uploaded once CI was green on 48123fa, so the shipped privacy manifest matches the label (the build number is the commit count). No tag pushed; Xcode Cloud untouched.
- **App Store Connect, done in the browser with the owner's permission (2026-10-29):** App Privacy published (privacy URL; Email Address, Photos or Videos, Other User Content, User ID, Other Data Types — App Functionality, linked, not tracking); version 1.0 listing (description, promotional text, keywords, support + marketing URLs, copyright); App Information (subtitle, Lifestyle / Productivity); age rating questionnaire → **4+**; TestFlight Test Information (beta description, feedback email, marketing + privacy URLs, review contact, review notes with the demo account); external group **Friends** with build 56, **submitted for Beta App Review (Waiting for Review)**; public link **https://testflight.apple.com/join/88BuzSRc** (open to anyone, no limit — testers can join once the build is approved). The owner accepted the updated Apple Developer Program License Agreement themselves. Export compliance needed no answer (Info.plist key). "Sign-in required" is off for Beta App Review because an account is optional; the demo address and code are in the review notes.
- `/grill-with-me` isn't installed in this setup, so the §12 attack was done by hand as the line-by-line checklist.

**Files changed:** `ios/Folio/Resources/PrivacyInfo.xcprivacy`, `ios/Folio/Features/PrivacyCover/PrivacyCoverModifier.swift`, 25 views moved from `inkTertiary` to `inkSecondary`, `shared/design-tokens.json` (inkSecondary 66 % / 64 %), `ios/FolioUITests/AccessibilityAuditUITests.swift`, `api/src/lib/ratelimit.ts`, `api/src/routes/auth.ts`, `api/test/phase14.test.ts`, `web/src/pages/privacy.astro`, `docs/APPSTORE.md`, `docs/appstore/*`.

**Screenshots:** `p3-00-default.png`, `p3-01-reduce-transparency-increase-contrast.png`, `p3-02-ax5.png`; App Store set in `docs/appstore/`.

**Tests:** API 62 (new: no raw IP in rate-limit rows); web 35 unit + 15 build checks; iOS unit tests pass; CI green on 3eca5de (iOS, API & web, secret scan). Accessibility audit (on demand): `TEST_RUNNER_FOLIO_A11Y_AUDIT=1 xcodebuild test … -only-testing:FolioUITests/AccessibilityAuditUITests`.

**Security:** gitleaks history clean; working-tree hits only in git-ignored build output and the throwaway `api/.dev.vars`; REVIEW_CODE set by you (never in a file).

**Deviations from SPEC:**
1. Weekday initials use `inkSecondary` instead of `inkTertiary` (SPEC §6.2) for AA contrast.
2. `inkSecondary` is a little darker (66 % instead of 60 % in light mode) on iOS and the web.

**Manual steps needed from the owner:**
1. Wait for Apple's Beta App Review e-mail (usually within a day), then send your friend https://testflight.apple.com/join/88BuzSRc.
2. Only if you want: tick "Sign-in required" in TestFlight → Test Information and type the demo account yourself (user review@devilsense.com, password = your review code). Not needed — the account is optional and the notes explain it.

**Open questions for the Architect:** none.

**Known issues:** none new beyond Part 2's.

### Still needed before a public App Store release
1. Final name.
2. Final app icon (the current one is a placeholder).
3. Legal review of the Privacy Policy and Terms.
4. US encryption year-end self-classification (your adviser).
5. A VoiceOver walk-through on your iPhone before declaring accessibility labels.
6. A device Instruments run (Animation Hitches).
7. Google OAuth consent screen verification.
8. Decide when to turn `REVIEW_ENABLED` off.
9. EU Digital Services Act trader declaration (left for the public launch, as you asked).
10. App Store screenshots aren't uploaded yet (they're in `docs/appstore/`; needed for the App Store submission, not for TestFlight).

**Next phase ready:** this was the last phase.
