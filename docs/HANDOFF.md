# Folio — Handoff

The next session starts here. Read this, then `CLAUDE.md`, `docs/SPEC.md`, `docs/PHASES.md` and the last entries of `docs/DECISIONS.md`. Updated at the end of every batch.

_Last updated: 2026-10-27, start of Batch D._

## Where things stand

| Phase | State |
|---|---|
| 0–8 | ✅ Done (setup, design system, data + crypto, calendar, composer, To-do, Journal + categories, onboarding/tour/Profile, dictation + ✦). |
| Batch C fixes | In Batch D, Part 1. |
| Recently Deleted (SPEC §5.2) | In Batch D, Part 2. New feature, not a numbered phase. |
| 11 Website | In Batch D, Part 3 (`/web`). |
| Xcode Cloud → TestFlight | In Batch D, Part 4. |
| 9 Backend, 10 Sign-in + sync, 12 Web app, 13 Motion polish, 14 Release | ⬜ Not started. |

Order so far: Batch A = Phases 1–3, Batch B = 4–6, Batch C = B fixes + 7–8, Batch D = C fixes + Recently Deleted + 11 + Xcode Cloud.

## Repo map

- `ios/project.yml` → XcodeGen. The `.xcodeproj` is git-ignored: after adding/removing files or editing the yml, run `cd ios && xcodegen generate`.
- `ios/Folio/{App,DesignSystem,Models,Features/*,Services/*}`; tests in `ios/FolioTests` (Swift Testing), `ios/FolioUITests` (XCTest), `ios/FolioCryptoTests`.
- `ios/Folio/Services/Store/DiaryStore.swift` is the single `@Observable` store (all queries, CRUD, markers, export inputs).
- `shared/` design tokens + Markdown/crypto fixtures (used by iOS and later the web app).
- `web/` Astro site (Phase 11). `api/` empty until Phase 9.
- `scripts/`: `sim-shot.sh` (screenshot), `contact-sheet.swift`, `setup-hooks.sh` (gitleaks hook, run once per clone).

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

CI (GitHub Actions): `ios.yml` (test + Release build on macos-26), `node.yml` (api/web: `npm ci --ignore-scripts`, audit, test), `secrets.yml` (gitleaks). Check with `gh run list --limit 5`.

## Screenshots and recordings

- `scripts/sim-shot.sh <udid> <out.png> <wait> [launch args…]` relaunches the app in **en_GB** and saves a 1200 px PNG.
- Common args: `-hasOnboarded YES -FolioSkipGreeting YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30 -FolioTab todo|journal|profile -FolioSelectDay 2026-10-25 -FolioOpen …` — full list in `ios/Folio/App/DebugLaunchOptions.swift`.
- Dark mode: `xcrun simctl ui "$SIM" appearance dark` (back to `light` afterwards).
- Recordings: `xcrun simctl io "$SIM" recordVideo --codec h264 out.mov` (Ctrl-C / kill -INT to stop), then `ffmpeg -i out.mov -vf "setpts=PTS/2,scale=480:-2" -an -c:v libx264 -crf 30 out.mp4` — tune speed/crf until < 1 MB.
- Contact sheet: `swift scripts/contact-sheet.swift docs/screenshots/<batch>/00-contact-sheet.png 5 "Title" <pngs…>`.
- Web: `cd web && npm run build && npm run preview`, then Playwright (MCP) screenshots; Lighthouse via `npx lighthouse <url> --only-categories=performance,accessibility,best-practices,seo --chrome-flags=--headless`.

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

## Open issues

- Speech-recognition permission prompt on a real device: unknown until the owner tests on TestFlight.
- iPad split view (§6.16) deferred to Phase 13.
- Phase 9/10 not started: sign-in buttons are DEBUG-only; Release shows Continue (guest).

## What's next

Finish Batch D (see below once updated), then Phase 9 (backend) on the owner's go-ahead.
