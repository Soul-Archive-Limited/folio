# Folio — Handoff

The next session starts here. Read this, then `CLAUDE.md`, `docs/SPEC.md`, `docs/PHASES.md` and the last entries of `docs/DECISIONS.md`. Updated at the end of every batch.

_Last updated: 2026-10-29, end of Batch G (Phases 13 and 14 done; TestFlight build for the external group "Friends")._

## Batch G status (resume here)
- Part 1: skipped — the owner hadn't tested 0.1.0 (49) yet. Their notes → next batch's Part 1.
- ✅ Part 2: Phase 13 (DECISIONS 202–208): iPad split view, motion fixes, main-thread fixes on 10k entries, web motion + idle preload; before/after clips `docs/screenshots/batch-g/rec-0*.mp4`.
- ✅ Part 3: Phase 14 (DECISIONS 209–211): privacy manifest + label answers, hashed IPs in rate limits (API version 0cd68092), accessibility audit + fixes, §12/§13 checklist in PHASES.md, `docs/APPSTORE.md`, App Store screenshots `docs/appstore/`, TestFlight **0.1.0 (56)** uploaded from this Mac; App Store Connect filled from APPSTORE.md in the browser (App Privacy published, listing, age rating 4+, Test Information); external group "Friends" with build 56 **submitted for Beta App Review**; public link https://testflight.apple.com/join/88BuzSRc (works once approved). EU trader declaration and App Store screenshots upload are left for the public launch.
- **Next session:** check Beta App Review's result for build 56; the owner's and their friend's test notes; then the public-release list at the end of `docs/reports/batch-g.md` (final name, icon, legal review, …).

### Phase 13/14 tools
- Hitch audit (Simulator): `-FolioHitchLog YES -FolioPerfScript YES` on a 10k diary (`-FolioStressData YES` once), then read `Documents/hitches.log` from the app container; marks split the flows. Instruments' Animation Hitches refuses the Simulator — use a device.
- Accessibility audit: `TEST_RUNNER_FOLIO_A11Y_AUDIT=1 xcodebuild test … -only-testing:FolioUITests/AccessibilityAuditUITests` (~10 min). Contrast/clipping on Liquid Glass are printed but don't fail (false positives; measure pixels instead).
- Recordings: `TEST_RUNNER_FOLIO_RECORDING=1 … -only-testing:FolioUITests/MotionRecordingUITests/<test>` while `simctl io recordVideo` runs.
- App Store screenshots: Simulator status bar `xcrun simctl status_bar <udid> override --time 9:41 …`, full-size `simctl io screenshot`, then `sips -s format jpeg` (App Store Connect rejects PNG alpha). iPad landscape via the Simulator tool's rotate.

### Local web + API testing (Batch F)
- `cd api && npx wrangler dev --ip 127.0.0.1 --port 8787` (local D1/R2; `api/.dev.vars` holds generated throwaway values: OTP_PEPPER, TOKEN_ENCRYPTION_KEY, REVIEW_CODE, Cloudflare's test TURNSTILE_SECRET — never real secrets; regenerate if missing). Apply local migrations with `npx wrangler d1 migrations apply folio-db --local`.
- `cd web && npm run build && node ../scripts/web-local-server.mjs dist 8788` → http://localhost:8788/app (Pages-like headers/rewrite, `/api` + socket proxied with the production Origin). Turnstile on localhost uses Cloudflare's always-pass test keys.
- Simulators against it: live UI steps take `FOLIO_API_BASE=http://127.0.0.1:8787/api/`, e.g. `FOLIO_REVIEW_CODE=$(grep ^REVIEW_CODE= api/.dev.vars | cut -d= -f2) scripts/sync-live-test.sh <udid> testA1SignInNewAccount FOLIO_API_BASE=http://127.0.0.1:8787/api/`; link the browser with `testA2ApproveLink FOLIO_LINK_TEXT=<the QR's data-link attribute>`.
- Email codes are limited to 3 per address per 15 min; on the *local* DB clear with `npx wrangler d1 execute folio-db --local --command "DELETE FROM rate_limits"`.
- Web screenshots/Lighthouse: `playwright-core` 1.64.1 + `lighthouse` 13.5.0 installed in the session scratchpad (not the repo), Brave as the browser; Playwright's video needs a separate ffmpeg download, so record by screenshot frames + system ffmpeg instead.

## Where things stand

| Phase | State |
|---|---|
| 0–8 | ✅ Done (setup, design system, data + crypto, calendar, composer, To-do, Journal + categories, onboarding/tour/Profile, dictation + ✦). |
| Batch C fixes | ✅ Batch D Part 1. |
| Recently Deleted (SPEC §5.2) | ✅ Batch D Part 2 (schema v3). |
| 11 Website | ✅ Batch D Part 3 (`/web`). Live: Pages project `folio` builds every push to main. |
| Xcode Cloud → TestFlight | ✅ Workflow "TestFlight"; build 1 (0.1.0 (1)) installed on the owner's iPhone. One Xcode Cloud build left in the budget. Builds now come from this Mac (`scripts/testflight.sh`): 0.1.0 (43) is Batch E's. |
| 9 Backend | ✅ Batch E (deployed). |
| 10 Sign-in + sync | ✅ Batch E. |
| 12 Web app (+ Turnstile) | ✅ Batch F (live at /app; owner's Brave test pending). |
| 13 Motion polish | ✅ Batch G Part 2. |
| 14 Release | ✅ Batch G Part 3 (TestFlight external beta; public-release list in the Batch G report). |

Order so far: Batch A = Phases 1–3, Batch B = 4–6, Batch C = B fixes + 7–8, Batch D = C fixes + Recently Deleted + 11 + Xcode Cloud, Batch E = D fixes + 9 + 10 + TestFlight, Batch F = improvements + 12 + TestFlight, Batch G = 13 + 14 + external TestFlight.

## Repo map

- `ios/project.yml` → XcodeGen. The `.xcodeproj` is git-ignored: after adding/removing files or editing the yml, run `cd ios && xcodegen generate`.
- `ios/Folio/{App,DesignSystem,Models,Features/*,Services/*}`; tests in `ios/FolioTests` (Swift Testing), `ios/FolioUITests` (XCTest), `ios/FolioCryptoTests`.
- `ios/Folio/Services/Store/DiaryStore.swift` is the single `@Observable` store (all queries, CRUD, markers, export inputs).
- `shared/` design tokens + Markdown/crypto fixtures (used by iOS and later the web app).
- `web/` Astro site: `src/config/site.ts` (all CTAs), `src/data/faq.ts`, `src/components/HeroCalendar.tsx` (hero island), `public/_headers`. Web app: `src/app/{lib,ui}`, `src/pages/app.astro`, `src/config/app.ts` (Turnstile site key).
- `api/` Worker (Hono, D1, R2, UserHub). `cd api && npm test`.
- `scripts/`: `sim-shot.sh` (screenshot), `contact-sheet.swift`, `setup-hooks.sh` (gitleaks hook, run once per clone), `write-build-number.sh` (XcodeGen preGenCommand), `testflight.sh` (fallback upload only).
- `ios/ci_scripts/ci_post_clone.sh`: Xcode Cloud installs XcodeGen and generates the project.

## Build, run, test

Simulator: iPhone 17 Pro, iOS 26.5, Xcode 27.1. Find its id with `xcrun simctl list devices booted`.

```bash
cd ios && xcodegen generate
```

```bash
cd ios && xcodebuild test -project Folio.xcodeproj -scheme Folio -destination "id=$SIM" -derivedDataPath build/DerivedData
```

Unit tests only (faster): add `-only-testing:FolioTests -only-testing:FolioCryptoTests`.

Build and install the DEBUG app for screenshots:

```bash
cd ios && xcodebuild build -project Folio.xcodeproj -scheme Folio -destination "id=$SIM" -derivedDataPath build/DerivedData && xcrun simctl install "$SIM" build/DerivedData/Build/Products/Debug-iphonesimulator/Folio.app
```

Release check (what CI does): `xcodebuild build -configuration Release -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO`.

Website:

```bash
cd web && npm ci && npm test
```

`npm test` = build (tokens → Astro → CSP script hashes into `dist/_headers`) + 13 checks. `npm run dev` for local work.

## TestFlight (Xcode Cloud) — budget rule

The owner allows only about **two Xcode Cloud builds across all 14 phases** (monthly hour limit). The workflow **TestFlight** starts **only on git tags beginning `testflight-`** (plus a manual start); pushes to main never build. It archives (no tests — GitHub Actions runs them) and sends to the internal group **Owner**. Never push a `testflight-` tag unless the owner asks. Build 1 = tag `testflight-0.1.0` (Batch D); one build left for later.

- Build number: `CI_BUILD_NUMBER` on Xcode Cloud, git commit count locally (`ios/Config/BuildNumber.xcconfig`, generated). Marketing version 0.1.0 in `project.yml`.
- App Store Connect app: **Folio Diary**, bundle `com.devilsense.folio`, SKU per the record, team 25DH3LUCPC. Xcode on this Mac is signed in (team Soul Archive Ltd).
- Fallback if Xcode Cloud is down: `scripts/testflight.sh` (archives and uploads through Xcode's account; build number must exceed the last Xcode Cloud one).
- Website deploys are free: Cloudflare Pages builds every push once connected (root `web`, build `npm run build`, output `dist`).

CI (GitHub Actions): `ios.yml` (test + Release build on macos-26), `node.yml` (api/web: `npm ci --ignore-scripts`, audit, test), `secrets.yml` (gitleaks). Check with `gh run list --limit 5`.

## Screenshots and recordings

- `scripts/sim-shot.sh <udid> <out.png> <wait> [launch args…]` relaunches the app in **en_GB** and saves a 1200 px PNG.
- Common args: `-hasOnboarded YES -FolioSkipGreeting YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30 -FolioTab todo|journal|profile -FolioSelectDay 2026-10-25 -FolioOpen …` — full list in `ios/Folio/App/DebugLaunchOptions.swift`.
- Dark mode: `xcrun simctl ui "$SIM" appearance dark` (back to `light` afterwards).
- Recordings: `xcrun simctl io "$SIM" recordVideo --codec h264 out.mov` (Ctrl-C / kill -INT to stop), then `ffmpeg -i out.mov -vf "setpts=PTS/2,scale=480:-2" -an -c:v libx264 -crf 30 out.mp4` — tune speed/crf until < 1 MB.
- Contact sheet: `swift scripts/contact-sheet.swift docs/screenshots/<batch>/00-contact-sheet.png 5 "Title" <pngs…>`.
- Recently Deleted shots: `TEST_RUNNER_FOLIO_SHOTS=<abs folder> xcodebuild test … -only-testing:FolioUITests/ScreenshotUITests`. Paced flow for recordings: `TEST_RUNNER_FOLIO_RECORDING=1 … -only-testing:FolioUITests/RecentlyDeletedUITests` while `simctl io recordVideo` runs.
- Web: there's **no Chrome** on this Mac, so Playwright MCP fails; use `playwright-core` + Lighthouse with Brave (`executablePath: /Applications/Brave Browser.app/Contents/MacOS/Brave Browser`, `CHROME_PATH` for Lighthouse), installed in the session scratchpad, not the repo. Serve `web/dist` with a tiny Node server that applies `_headers` and gzip so CSP and scores are realistic. Full-page shots need `img.decode()` first or lazy images come out blank.

## Hard-won gotchas

1. **zsh doesn't word-split `$A`.** `ARGS="-a 1 -b 2"; cmd $ARGS` passes one argument. Use arrays (`args=(-a 1 -b 2); cmd "${args[@]}"`) or write the args out.
2. **UI tests wipe Simulator app data.** After any `xcodebuild test` run, re-seed before screenshots: launch once with `-FolioResetData YES -FolioSampleData YES`.
3. **Synthetic taps on Liquid Glass buttons need ~0.15 s** (`press(forDuration: 0.15)`), ~0.3 s inside horizontal scroll views. Not an app bug.
4. **HEIC decodes run on their own serial `DispatchQueue`** (`DisplayImageCache.decode`). ImageIO's HEIC decoder blocks its thread; on the Swift concurrency pool it starves everything.
5. **Context7 may be unreachable.** Fall back to the installed SDK's `.swiftinterface` files (`xcrun --show-sdk-path --sdk iphoneos` → `System/Library/Frameworks/X.framework/Modules/…`). Log the source in DECISIONS.md.
6. **Toasts must be hosted inside each tab's content** (`toastHost`), not on the `TabView`, or Undo doesn't receive taps.
7. **Inset-grouped `List` sections draw a panel behind rows**; glass content in a row shows as a band. Put glass headers/chips in a section header or outside the List.
8. **Separate glass shapes inside a horizontal ScrollView** need one shared `GlassEffectContainer`, or a lighter band appears.
9. **SwiftData batch delete (`context.delete(model:)`) silently fails** on Entry → EntryPhoto; delete object by object.
10. **The privacy cover only engages after the first `.active`** (cold launch passes through `.inactive`).
11. **Simulator can't run Apple's on-device model or record the Mac mic**: use `-FolioDemo dictation|intelligence` for screenshots and label them "simulated".
12. **`#Preview`s using sample data must be `#if DEBUG`**, or Release builds fail (CI checks Release).
13. **Never set the team in Xcode's Signing tab** — it lives in `ios/project.yml` (`DEVELOPMENT_TEAM 25DH3LUCPC`).
14. **The iOS 26 tab bar's frame never changes when it minimises**; only which subview is hidden does. `TabBarShapeReader` reads that (public `UIView` state) so To-do's quick-add bar can drop beside the circle. `.tabViewBottomAccessory` was rejected (hidden behind the keyboard; per-tab `isEnabled` is iOS 26.1+).
15. **Live queries must filter `trashedAt == nil`** (Recently Deleted). Permanent deletes are `deletePermanently(_:)`; everyday Delete is `trash(_:)`.
16. **Pin npm packages to releases ≥ 2 weeks old** (`npm view <pkg> time --json`), and run `npm audit`.
17. **Xcode Cloud warns "scheme may only exist locally"** — expected, because the project is generated in `ci_post_clone.sh`.
18. **XCUITest accessibility snapshots run on the app's main thread** — never measure hitches while a UI test drives the app; use the in-app `PerfDriver`.
19. **Paging scroll views keep their pixel offset when the page width changes** — key them by width (`.id(layout.panelWidth)`), or iPad shows two half months.
20. **Every flow reading `SystemLanguageModel.default.availability` makes a synchronous XPC call** — it's cached for 30 s in `WritingAssistant`.
21. **Local email codes: 3 per address per 15 min** — clear `rate_limits` in the local D1 between web script runs.

## Open issues

- Build 1 (0.1.0 (1), tag `testflight-0.1.0`) is installed on the owner's iPhone. TestFlight shows builds to the Apple Account that accepted the invitation email (the owner's phone uses a personal account; the tester is admin@devilsense.com), so new testers must open the invite on the device.
- **Owner's iPhone test of build 1 (2026-10-27)** — to fix in Batch E:
  1. Speech: iOS **does** show the Speech Recognition prompt after the microphone one (answers the Phase 8 open question). SPEC §7 wants a glass explainer before each system prompt, so the explainer must cover speech too.
  2. Photos: no permission prompt, gallery opens directly — correct (PhotosPicker runs out of process, SPEC §7).
  3. A composer item about the Photos button and the calendar/date icon on the same line — the owner's sentence was cut off; ask what they meant.
  4. Onboarding: after typing a name, the keyboard stays up on the next page and can't be dismissed by tapping.
  5. Tour: the next tip appears while the previous step's screen is still showing; no step count ("2 of 6"); it should move to the next screen/step by itself instead of waiting.
  6. Fast Calendar ↔ Journal tab switching: a photo briefly draws outside its container's rounded border.
  7. Photo tiles on the calendar: the day number and dots are hard to read on some photos (needs a scrim/dim).
  8. No way to delete a page from a list: add swipe and long-press Delete (day panel, Journal) — currently only entry detail → ••• → Delete.
  9. Draft bug: reopening an entry that was already saved still asks "Continue your draft?". Only unsaved changes should prompt.
  10. Share: unclear what is shared. Make it explicit (e.g. text vs text + photos, with a preview).
  Recently Deleted (delete, Undo, restore) worked on device.
- Legal pages need the owner's legal review; US year-end encryption self-classification is an open question for their adviser (DECISIONS 143).
- Apple web sign-in: the owner configured the Services ID domain + return URL; a real browser sign-in is still untested.
- Phase 13's 120 fps target is unverified on a device (Simulator numbers in DECISIONS 206).
- `REVIEW_CODE` set by the owner (Batch G); `REVIEW_ENABLED` stays `"true"` until the app is approved for the App Store.

## What's next

The owner tests the Friends build (iPhone + web) and sends notes → next batch's Part 1. Before a public App Store release: the list at the end of `docs/reports/batch-g.md`. TestFlight builds come from `scripts/testflight.sh` (Xcode Cloud budget rule above).
