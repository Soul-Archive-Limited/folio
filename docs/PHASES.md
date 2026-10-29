# Folio — Phases

The roadmap. Each phase ends with a Phase Report (SPEC §18) and waits for the owner's go-ahead before the next one starts. Skills to use per phase are in `CLAUDE.md`.

Status key: ✅ done · 🟡 in progress · ⬜ not started

| # | Phase | Scope (SPEC refs) | Status |
|---|---|---|---|
| 0 | Setup | Repo layout, CLAUDE.md, docs, security guardrails (§13.4–13.6), XcodeGen project, empty app, LICENSE, README, first push | ✅ |
| 1 | Design system, greeting, privacy cover | Colour tokens, category palette, type scale, spacing, glass components, `AuraBackground`, toast, motion + haptics, accessibility fallbacks, DEBUG Design Gallery, greeting intro, app-switcher cover (§3, §4) | ✅ |
| 2 | Data + crypto core | SwiftData models, `DayKey`, sync fields, `@Observable` store, `MarkdownCodec` + shared fixtures, image pipeline, `PreviewData`, `FolioCrypto` + shared vectors, recovery key, X25519 link handshake, greeting summary on real data (§5, §10.3, §10.4) | ✅ |
| 3 | Tabs + Calendar | Native TabView shell, floating "+", Calendar tab, endless month paging, all cell states, filter, Today pill, day panel, collapse to week, Jump sheet, long-press menus, VoiceOver + rotor (§2, §6.2, §6.3, §15.1) | ✅ |
| 4 | Composer + entry detail | Composer half sheet, rich text, photos, drafts, entry detail with zoom (§5.1, §6.4, §6.5) | ✅ |
| 5 | To-do | To-do tab, task composer, complete/undo flow, quick-add (§6.7, §6.8) | ✅ |
| 6 | Journal + Categories | Journal tab (Timeline / Photos), categories manager (§6.6, §6.10) | ✅ |
| 7 | Onboarding + tour + Profile | Welcome pages, name, sync choice UI, TipKit tour, Profile tab in guest mode (§6.1 steps 1–5 and 8, §6.9, §6.15) | ✅ |
| 8 | Dictation + AI | SpeechAnalyzer dictation overlay, Foundation Models ✦ menu, permission explainers (§6.11, §6.12, §7, §8, §9) | ✅ |
| 9 | Backend | Worker, D1 schema, R2, `UserHub`, Better Auth (Apple/Google/email OTP via Resend), sync, blobs, linking, delete account, rate limits, admin usage (§10, §13, §15.2) | ✅ |
| 10 | iPhone sign-in + sync | Sign-in flows, recovery key + unlock screens (§6.1 steps 6–7, §6.13), Keychain, DK + recovery key, sync engine, live socket, background refresh, QR device linking, delete account in-app (§10.2–10.6) | ✅ |
| 11 | Website | Astro marketing site, legal pages, support/FAQ, headers, SEO (§11.1, §11.2, §14) | ✅ |
| 12 | Web app | `/app` sign-in + unlock, calendar, entries, tasks, Tiptap editor, live sync, delete account (§11.3) | ✅ |
| 13 | Motion polish | Hitch audit with Instruments, 120 fps pass, Reduce Motion pass, web motion, iPad split view (§3.6, §6.16, §15.1) | ✅ |
| 14 | Release | Privacy manifest, App Store checklist, accessibility audit, review account, TestFlight (§12) | ✅ |

Phases 3–7 follow the owner's playbook order (confirmed 2026-10-26). Phases 1–3 run as **Batch A**, 4–6 as **Batch B**, the Batch B fixes plus 7–8 as **Batch C**, and the Batch C fixes, Recently Deleted, Phase 11 and Xcode Cloud TestFlight builds as **Batch D**.

### Batch D checklist
- [x] Part 1 — Batch C fixes
- [x] Part 2 — Recently Deleted (SPEC §5.2)
- [x] Part 3 — Phase 11 website
- [x] Part 4 — Xcode Cloud → TestFlight (workflow set up; first build from tag `testflight-0.1.0`)

### Batch E checklist
- [x] Part 1 — Batch D fixes (owner's iPhone test of 0.1.0 (1))
- [x] Step 0 — Release archive: 0 warnings; CI fails on any Release warning
- [x] Part 2 — Phase 9 backend deployed on folio.devilsense.com/api, live smoke test passed
- [x] Part 3 — Phase 10 iPhone sign-in, encryption, sync (live two-Simulator test passed, /vibesec done)
- [x] Part 4 — TestFlight build from this Mac + owner's test list (0.1.0 (43))

### Batch F checklist
- [ ] Part 1 — owner's iPhone test of 0.1.0 (43) (owner tests after this batch; fixes go in the next one)
- [x] Part 2 — Devices (model + OS, dates, encrypted rename), one request per photo, two-line recovery key, gitleaks full scan
- [x] Part 3 — Phase 12 web app at /app (+ Turnstile), tested on the local stack with a Simulator; deploy in Part 4
- [x] Part 4 — API deployed, web live via Pages (every push to main), TestFlight 0.1.0 (49), owner checklist in the Batch F report

### Batch G checklist
- [x] Part 1 — owner's test of 0.1.0 (49) + web app (not tested yet; notes go to the next batch)
- [x] Part 2 — Phase 13 motion & performance
- [x] Part 3 — Phase 14 compliance, App Review readiness, TestFlight 0.1.0 (56) for friends (Friends group, Beta App Review submitted, public link)

### Phase 14 — SPEC §12 / §13 checklist (2026-10-29)
**App Review (§12)**
- [x] 2.1 complete: no placeholder or beta text in the app; review account `review@devilsense.com` with a fixed code from the `REVIEW_CODE` Worker secret, rate-limited like any address, switchable with `REVIEW_ENABLED`; notes in `docs/APPSTORE.md`. Owner sets the 6 digits.
- [x] 4.8 Sign in with Apple first, same size as Google and email (onboarding and Profile).
- [x] 5.1.1 Privacy Policy linked in Profile → About and under the sign-in buttons; URL in APPSTORE.md; purpose strings (§7) only at use; everything works as a guest.
- [x] 5.1.1(v) Delete account in the app and on the web, with Apple token revocation (Phases 9–10, live-tested).
- [x] 5.1.2 Processors only: Cloudflare, Resend; Apple/Google only if chosen.
- [x] `requestReview` only behind Profile → Rate Folio.

**Privacy (§12)**
- [x] `PrivacyInfo.xcprivacy`: no tracking, no domains, Email Address + Photos or Videos + Other User Content + User ID + Other Data (App Functionality, linked), UserDefaults `CA92.1` only (DECISIONS 209, 212).
- [x] Privacy label published in App Store Connect; the E2E-encrypted diary content is declared (owner decision, DECISIONS 212).
- [x] GPS/EXIF stripped (Phase 2); content hidden in the app switcher (now only in the tree while covering); no content in logs (Phase 10 /vibesec, re-checked).

**Other (§12)**
- [x] `ITSAppUsesNonExemptEncryption = NO`; Apple's table checked (OS encryption only → no documentation). US year-end self-classification stays with the owner's adviser (DECISIONS 143).
- [x] Age rating answers → 4+ (APPSTORE.md).
- [ ] EU DSA: trader Soul Archive Ltd — left for the public launch (owner).
- [ ] Google OAuth consent screen verification — owner, before public release (APPSTORE.md list).
- [x] Accessibility Inspector audit on 13 screens, default + AX5; fixes in DECISIONS 211; Reduce Motion / Transparency / Increase Contrast / AX5 screenshots.
- [x] Works offline, signed out and after account deletion (guest mode; Phase 10 live tests; airplane-mode run from Batch E).
- [x] "© 2026 Soul Archive Ltd" in Profile → About and on the website footer.

**Secrets & security (§13)**
- [x] 1–2 No secrets in the app or website (bundle re-checked); server secrets only via `wrangler secret put`.
- [x] 3–4 `.dev.vars*`, `.env*`, `*.p8`, `*.pem`, `*.key` ignored in `.gitignore`, `.dockerignore`, `.cfignore`; none tracked.
- [x] 5 gitleaks: 53 commits clean; working-tree hits only in git-ignored build output and the throwaway `api/.dev.vars`; pre-commit hook + CI job on.
- [x] 6 Dependabot on; `npm audit` 0 vulnerabilities (api, web).
- [x] 7 zod on every body, parameterised D1 (generated `?n` placeholders only), userId from the session, generic errors; rate-limit keys hold no raw IPs (DECISIONS 210).
- [x] 8–9 HTTPS/HSTS, authenticated WebSocket; Keychain + file protection; ATS default.
- [x] 10 /vibesec final pass (api, web, iOS): no new findings beyond 210.

## Log

### Batch G Part 2 — Phase 13 motion & performance (2026-10-29)
- iPad: sidebar-adaptable tabs; Calendar as a resizable split (month column · day panel / entry detail); pagers rebuild on width change (fixes two half months on iPad).
- Motion: filters animate (calendar markers fade, Journal/To-do rows move), day title cross-fades, sync status and guest ↔ signed-in animate, all curves from `FolioMotion`, Reduce Motion honoured by models too.
- Performance on 10,000 entries (Simulator; DEBUG `HitchMonitor` + in-app `PerfDriver` + Time Profiler): Journal tab switch 444 → ~250 ms worst frame; composer no longer makes a synchronous model-availability XPC call per redraw; cached day-cell labels; Journal scroll 0 late frames.
- Web: hover only on mouse devices, no tap flash/delay, reduced motion cross-fades, lazy chunks preload when idle (first composer 158 → 9 ms); CLS 0 and no frame over 17 ms on every flow.
- Before/after clips `docs/screenshots/batch-g/rec-0[1-5]-*.mp4`.

### Batch F Part 3 — Phase 12 web app (2026-10-29)
- `/app`: Apple / Google / email + Turnstile sign-in; unlock by QR from the iPhone (default) or recovery key; Trust this browser for 30 days; recovery-key setup for accounts that start on the web.
- ≥ 1024 px glass sidebar, square month grid with every cell state and photo tiles, day panel, right-side composer; < 768 px floating tab bar and bottom drawer.
- Calendar, day panel, entries with encrypted photos (upload, view all three renditions), Tiptap editor on the shared Markdown fixtures, WebCrypto on the shared vectors, To-do with 1.2 s + Undo, categories, filters, Recently Deleted, theme, writing font, devices with encrypted names, sign out, delete account.
- Live socket while visible, pull on focus, optimistic edits with rollback; diary only in memory (or the trusted key in IndexedDB); one session cookie; own CSP.
- Tested against wrangler dev with Simulator A: QR and recovery-key unlock, edits both ways in ~1–3 s, photos both ways, trash/restore, delete account → D1/R2 empty. Lighthouse 99–100 (SEO 63: not indexed by design). /vibesec findings fixed.

### Batch F Part 2 — improvements (2026-10-29)
- Devices: "iPhone 15 Pro · iOS 27.1" / "Chrome on macOS" / "Simulator", added + last seen (hourly), "This device" badge, rename any device (sealed with the Data Key on the session row).
- Photos upload in one request each (three renditions); 600 photos/hour, 3,000/day; old per-rendition route kept for build 43.
- Recovery key on two balanced lines (4-5-4 + 4-5-4).
- gitleaks: history and tracked files clean; live D1 had no leftover test sessions.

### Batch E — Phase 9 deploy + Phase 10 (2026-10-29)
- API live on `folio.devilsense.com/api/*` (D1 `folio-db`, R2 `folio-blobs`, UserHub DO); admin endpoint dropped (no Cloudflare Access); web email sign-in closed until Turnstile (Batch F); blob uploads 180/hour.
- iPhone: Sign in with Apple (nonce), Google (ASWebAuthenticationSession, no SDK), email code (one-time-code autofill); session in Keychain (this device), Data Key + recovery key in iCloud Keychain.
- Recovery key screen (copy / save / print / confirm last 4); unlock by iCloud Keychain, QR from another device (Face ID approval) or recovery key; Profile → Link a browser or device.
- Sync engine: dirty tracking, 2 s debounced push, pull only when the live socket's cursor moved, WebSocket in the foreground, background refresh while unlocked, backoff + Retry-After, encrypted thumb/display/full blobs, guest → account upload with progress, last-writer-wins, tombstones, Recently Deleted across devices.
- Profile signed in: status, last synced, Sync now, Devices, Recovery key, Link, Sign out (keep or remove), Delete account (re-auth + DELETE, keep or erase).
- Live test on three Simulators against the deployed API; delete account leaves nothing in D1 or R2.

### Phase 0 — Setup (2026-10-25)
- Repo created at `github.com/Soul-Archive-Limited/folio`.
- gitleaks pre-commit hook in `.githooks/`, CI secret scan, Dependabot.
- XcodeGen project `ios/project.yml` (iOS 26.0, Swift 6); empty app shows "Folio".
- CI green on first push: secret scan, iOS build + test (macos-26), API & web.

### Phase 1 — Design system, greeting, privacy cover (2026-10-26)
- Tokens from `shared/design-tokens.json` → asset catalog (light/dark/high-contrast); 12 AA-checked category colours.
- Type scale, spacing, radii, spring motion + Reduce Motion fallbacks, haptics vocabulary.
- Components: `FolioGlassModifier` (Reduce Transparency / Increase Contrast fallbacks), `GlassCard`, `Chip`, `GlassIconButton`, `EmptyStateView`, toasts with Undo, `AuraBackground`, `AppMark`.
- DEBUG Design Gallery (`-FolioScreen gallery`).
- Greeting intro (full pool, no-repeat, specials, tap-to-skip, skip on quick resume) and app-switcher privacy cover.

### Phase 2 — Data + crypto core (2026-10-27)
- SwiftData schema v1 (`Category`, `Entry`, `EntryPhoto`, `TaskItem`, `UserSettings`) with sync fields, `#Unique`/`#Index`, migration plan; store in a `NSFileProtectionComplete` directory.
- `DayKey`/`MonthKey` floating days; `DiaryStore` (day queries, cached month markers, category CRUD + un-assign on delete, tombstones, greeting summary).
- Folio Markdown codec + `shared/markdown-fixtures.json`; photo pipeline (all metadata stripped, ≤ 2048 HEIC, 240 px thumb, `@concurrent`).
- `FolioCrypto`: data key, AES-256-GCM records with AAD, recovery key (Crockford base32) + HKDF envelope, X25519 device link; `shared/crypto-vectors.json` from WebCrypto.
- DEBUG sample data (40 entries, 25 tasks, 6 categories, generated photos) and 10k stress generator. Greeting summary uses live data.

### Phase 3 — Tabs + Calendar (2026-10-27)
- Native `TabView` (Calendar · Journal · To-do · Profile), tab-bar minimise on Journal/To-do, floating glass "+" with long-press menu.
- Calendar: endless month paging, every cell state (photo tile + "+N", category dots, task rings, all-done check, today, selected spring, out-of-month, filter fade), Today pill, category filter, long-press day menu.
- Day panel (entry cards, tasks that tick in place and stay), finger-tracking collapse to a swipeable week strip with snapping, Jump sheet (year strip 1900→+10, months with entry dots).
- VoiceOver labels + "Days with entries" rotor; AX-size list layout; 10k-entry performance test.
- Journal, To-do and Profile are placeholders; composers are placeholder sheets (Phases 4–7).

### Phase 4 — Composer + entry detail (2026-10-27)
- Half-sheet composer over the calendar (tap a day to move the entry), date pill back to 1900 with optional time, Save/Cancel with discard confirm.
- iOS 26 rich `TextEditor` limited to SPEC §5.1 via a formatting definition; Aa popover (5 inline + 5 block styles, tick checklist item); saved through `MarkdownCodec`.
- PhotosPicker (no permission), camera with explainer, photo strip (drag to reorder, × to remove), category chips with inline create, 2 s draft autosave + "Continue your draft?".
- Entry detail: zoom from the card, full-res carousel + full-screen pinch, share, change date, duplicate, delete with Undo toast, "Same day in other years".

### Phase 5 — To-do (2026-10-27)
- To-do tab: overdue → dated → undated (drag order), collapsible "Completed · N" (persisted), category filter chips, "All clear." empty state.
- Tick: fill + checkmark draw + strike-through + haptic, 1.2 s pause, then moves; tap again to cancel; 4 s Undo toast; untick in Completed is instant.
- Swipe actions (Done, Delete with confirm for notes, Edit, Date menu), glass quick-add bar recognising today/tomorrow, task composer sheet (also from long-press "+").
- UI test proving only Delete removes a task from the calendar; erase-all bug fixed.

### Phase 6 — Journal + Categories (2026-10-27)
- Journal Timeline (sticky month headers, 16:9 cover cards and text cards, zoom to detail), Photos (3-column masonry), category chips, "Write for a past day".
- Categories manager (reorder, swipe delete with counts, edit sheet with 12-swatch grid, 40 symbols, live chip preview, max 30), linked from Profile.
- Category filters on Calendar, Journal and To-do; tests for month grouping, caching, filters, masonry balance, reorder and edit validation.

### Batch B fixes (2026-10-27)
- "+" only on Calendar/Journal roots (morphs away on pushed screens); To-do gets a full-width quick-add with an expand button, a 60 pt scrim and a proper bottom inset; toasts rest above the bar and spring.
- Display photo rendition (1080 px HEIC) with schema v2 migration and backfill; drafts keep photos; file-protection/sync rule decided for Phase 10.

### Phase 7 — Onboarding, tour, Profile (2026-10-27)
- Onboarding: three welcome pages with scroll-tied parallax (assembling month, old date flipping in, privacy), name, sync choice (Apple / Google / email per brand rules; DEBUG toasts, Release guest-only), then greeting → tour.
- TipKit tour: six ordered glass tips that advance on the user's action, Skip tour, never repeat, replay from Profile → Help.
- Profile (guest): header with monogram and name editing, archive tiles that open filtered tabs, Account card, Categories, Appearance, Writing, Privacy, Your data (JSON + photos zip export, erase), Help, About.
- Composer tools now live in a glass row that works with or without the keyboard; Release build fixed and checked in CI.

### Phase 8 — Dictation + on-device intelligence (2026-10-27)
- Dictation: `SpeechAnalyzer` + `DictationTranscriber`, on device; glass capsule with live waveform, dim volatile words, finals inserted at the cursor, Pause/Done, model download progress, auto-stop (2 min silence / 30 min), one session at a time, "Dictate an entry".
- ✦ writing tools on `SystemLanguageModel.default` only: three title chips, grammar diff with Accept/Discard, find tasks to tick and add; rate-limited; hidden when unavailable with Profile explaining why; DEBUG switch to fake unavailable.
- Profile: Dictation & Intelligence section with dictation language. Erase now clears drafts too.

### Batch C fixes (2026-10-27)
- Profile "Writing since" uses the earliest day written for.
- Task composer: turning on Date scrolls the form to its top (Title visible above the full picker); category chips without the row panel.
- To-do quick-add follows the minimising tab bar into its row (no gap); `.tabViewBottomAccessory` checked and rejected (hidden behind the keyboard, per-tab variant needs iOS 26.1).

### Recently Deleted (2026-10-27)
- SPEC §5.2 written (plus §5 rule, §6.5/6.7/6.8/6.9/6.10, §10.5, §14.1).
- Schema v3 (`trashedAt` on Entry/TaskItem/Category, `Category.unassignedIDs`) with frozen v2 models and a lightweight migration; every live query skips trash.
- Delete → "Moved to Recently Deleted · Undo" (no confirmation); Recently Deleted screen (segments, days left, preview, swipe Restore/Delete now, Select, Empty, empty state); Profile row with count, quiet links on Journal and To-do; "Restored to Tue 27 Oct · Show".
- 30-day purge on launch, foreground and background refresh, on a clock that never runs backwards; export toggle; Erase empties it. 11 unit tests, migration test, UI test.

### Phase 11 — Website (2026-10-27)
- `/web`: Astro static + React island, paper light/dark from the shared tokens, self-hosted Instrument Serif, live calendar recreation in the hero phone (pauses for Reduced Motion and off screen).
- Pages: Home, Privacy, Terms, Support, Open source, Changelog, Delete account, 404; company footer; sitemap, robots, OG image, favicons.
- CTAs from `src/config/site.ts`, rendered only when set. No cookies, analytics or forms.
- `_headers` with SPEC §11.3 headers and build-time script hashes; `npm test` builds and runs 13 checks. Lighthouse ≥ 96 on every page.
- Deploy: waiting on the owner to connect Cloudflare Pages (root `web`, output `dist`, domain `folio.devilsense.com`).

### Xcode Cloud → TestFlight (2026-10-27)
- `ios/ci_scripts/ci_post_clone.sh` (XcodeGen), build number from `CI_BUILD_NUMBER`, `ITSAppUsesNonExemptEncryption = NO`, privacy manifest, `scripts/testflight.sh` fallback.
- App Store Connect app "Folio Diary"; workflow "TestFlight" builds only on `testflight-*` tags (owner's budget: about two builds across all phases) and sends to the internal group Owner.

### Batch D fixes (2026-10-28)
- One explainer for microphone + speech recognition; "Past day" pill in Journal; onboarding keyboard always dismissed.
- Tour rebuilt without TipKit: "n of 6", Back/Next/Skip, moves between screens itself, waits for transitions, auto-advances look-only steps.
- Photos clipped to their containers (incl. zoom sources); photo tiles get a scrim; swipe + long-press actions on entry cards; drafts only for real changes; Share menu (text / text + photos / image card); `emberStrong`/`emberText` tokens (website home accessibility 100).
