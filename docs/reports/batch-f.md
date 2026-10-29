# Batch F report

Batch F = owner's iPhone fixes (Part 1) · improvements (Part 2) · Phase 12 web app (Part 3) · TestFlight build and deploy (Part 4). Shape per SPEC §18, one section per part.

---

## Part 1 — Owner's iPhone test of 0.1.0 (43)

**Built:** nothing. The owner hasn't tested 0.1.0 (43) yet and will test the new build after this batch; findings become the next batch's Part 1.
**Next phase ready:** yes.

## Part 2 — Improvements

**Built:**
- **Devices:** each row shows model and OS ("iPhone 15 Pro · iOS 27.1", "Brave on macOS", "Simulator · iOS 26.5"), the date added, last seen (now written hourly, so "Active in the last hour" / "Last seen 3 hours ago"), and a "This device" badge. Any device can be renamed; the name is sealed with the Data Key on its session row, so only your devices can read it and it goes when the device signs out. The iPhone sends its model and OS at sign-in and again after OS updates (DECISIONS 189).
- **First sync of big diaries:** a photo's three renditions now upload in one request (`PUT /api/blobs/photo/:id`), with a limit of 600 photos an hour and 3,000 a day (was 60 photos an hour). A 500-photo diary uploads in one sitting. On the free plan, 500 photos cost about 500 Worker requests and 1,500 R2 writes; storage is the real limit and the 1 GB quota already bounds it (DECISIONS 190). Checked on a local server: the 25-photo sample diary made 25 photo requests instead of 75.
- **Recovery key:** the 26 characters sit on two balanced lines, 4-5-4 and 4-5-4, ending in exactly the 4 characters you type to confirm (no lone pair on a third line). The same grouping is used for copy, save, print and the web (DECISIONS 191).
- **Secrets:** a full gitleaks scan found no leaks in all 44 commits of history, and nothing in tracked files. The only folder-scan hits are git-ignored build output and the local throwaway `api/.dev.vars`. No `.p8`/`.pem`/`.key`/`.env` file was ever committed, and the review code is in no file. The live D1 had no leftover test sessions, so nothing needed pruning (DECISIONS 192).

**Files changed:** `api/src/routes/{account,blobs}.ts`, `api/src/lib/session.ts`, `api/migrations/0002_device_labels.sql`, `ios/Folio/Services/Account/{DeviceInfo,AccountModel+Manage,APIClient}.swift`, `ios/Folio/Features/Profile/{DevicesView,DeviceRow}.swift`, `ios/FolioCrypto/{RecordType,RecoveryKey}.swift`, `ios/Folio/Services/Sync/SyncEngine+Blobs.swift`, `shared/crypto-vectors.json`.

**Screenshots:** `docs/screenshots/batch-f/`
- `p2-01-devices-before.png` — Batch E: every row said "iPhone"
- `p2-01-devices-after.png` / `-dark.png` — model + OS, added, last seen, This device
- `p2-02-devices-rename.png` → `p2-02-devices-renamed.png` — renaming "Chrome on macOS" to "Studio Mac"
- `p2-03-recovery-key-before.png` — three lines with a lone "84"-style pair
- `p2-03-recovery-key-after.png` / `-dark.png` — two balanced lines
- `p2-04-first-sync-one-request-per-photo.png` — first sync of the sample diary

**Tests:** API 53 → 61 tests (one-request photos, limits, device names and labels, session probe, web Apple re-auth), all pass. iOS 161 app + 19 crypto tests, all pass (new: model names, photo body, device label crypto, JPEG sync copy). Live UI step `testF1DevicesAndRename` passes.

## Part 3 — Phase 12: web app at /app

PHASE 12 REPORT

**Built:**
- **Sign-in:** Continue with Apple (Services ID `com.devilsense.folio.web`), Google (Web client), and email code behind Turnstile. Turnstile loads only on the email step, and the page reloads after sign-in.
- **Turnstile:** you set the secret with `wrangler secret put`; the site key is in `web/src/config/app.ts`. Web email sign-in is now on: a browser request needs a valid Turnstile token (checked on production: a fake token gets `turnstile`; the old answer was `web_email_disabled`).
- **Unlock:** "Scan with your iPhone" is the default. The browser shows a QR code; the iPhone (Profile → Link a browser or device) seals the Data Key to it, and the server only relays. Or unlock with the recovery key. Optionally "Trust this browser for 30 days" (a non-extractable device key in IndexedDB). An account that starts on the web makes its recovery key in the browser.
- **Layout:** at 1024 px and wider, a glass sidebar (Calendar · Journal · To-do · Profile, "New entry", you + sync status), a square month grid with every cell state including photo tiles, the day panel on the right, and the composer as a right-side glass sheet so the calendar stays visible. Clicking another day while writing moves the entry there. From 768 to 1023 px a narrow rail; under 768 px it matches the iPhone, with the floating glass tab bar, the "+" button and a bottom-drawer composer.
- **Features:**
  - calendar (paging, jump to any month back to 1900, filter, Today, right-click or long-press for a new entry or task on a day) and the day panel;
  - entries with encrypted photos: upload up to 10, reorder, remove, and view all three renditions in the lightbox (Thumbnail · Display · Full);
  - formatted text via Tiptap, limited to SPEC §5.1;
  - tasks with the 1.2 s pause, tap to cancel, 4 s Undo, quick-add that understands "today" and "tomorrow", and a task composer;
  - categories (create, colour, reorder, delete → Recently Deleted with re-linking), filters, Recently Deleted (restore, delete now, select, empty, days left, 30-day purge);
  - name, theme, writing font, first weekday, default category, photo tiles, devices with encrypted names, sign out, and delete account.
  - Dictation and ✦ say "Available in the iPhone app".
- **Sync:** live socket while the tab is visible, pull on focus, optimistic edits with rollback. Diary content stays in memory only; the only cookie is the session cookie (plus a 10-minute one during an Apple/Google sign-in), so no banner. `/app` has its own strict CSP, `no-store` and `noindex`.
- **Website:** the "Open web app" button and "Open in browser" are on.
- **iPhone:** photos now sync as JPEG so browsers can show them (DECISIONS 193).
- **API:** `GET /api/auth/session`, plus a fix so re-signing in with Apple on the web works (Delete account; DECISIONS 194).

**Files changed:** 138 files in total this batch (`git diff --stat 3471d86`); the web app is `web/src/app/{lib,ui}/*`, `web/src/pages/app.astro`, `web/public/{_headers,_redirects}`, `web/test/*`.

**Screenshots / recordings:** `docs/screenshots/batch-f/00-contact-sheet.png` (42 shots), each screen at desktop (1440 × 900) and phone (390 × 844) size, light and dark:
- `w01-signin-*` — sign in: Apple, Google, email
- `w02-unlock-qr-*` — Unlock, QR for the iPhone (default), recovery key tab, Trust this browser
- `w03-calendar-*` — month grid with photo tiles, dots, task rings, today
- `w04-day-panel-phone-*` — the day panel under the grid on a phone
- `w05-composer-*` — composer as a right-side sheet (desktop) / bottom drawer (phone)
- `w06-entry-*` — entry with its photo, bold + highlight, "Same day in other years"
- `w07-journal-*` — Journal timeline with cover cards
- `w08-todo-*` — To-do with dates, overdue chips and quick-add
- `w09-recently-deleted-*` — a deleted task with "30 days left", Restore / Delete now
- `w10-profile-*` — Profile: archive tiles, account, sync, trusted browser, appearance
- `w11-devices-*` — Devices: Brave on macOS (this device), Simulator · iOS 26.5, encrypted rename
- `p3-sim-received-web-entry.png` — the entry and photo written on the web, on the Simulator
- `rec-edit-sim-to-web.mp4` (71 KB) — an entry renamed on the iPhone Simulator appears in the web app (Brave) about 2 s later

**Tests:**
- Web unit tests: 35 pass. That's WebCrypto against every vector in `shared/crypto-vectors.json` (records, blobs, base32, recovery envelope, X25519 link), and all 27 cases in `shared/markdown-fixtures.json`, also round-tripped through the editor. Typecheck clean; 15 build checks, including the web app's CSP, rewrite, noindex and sitemap.
- **End to end on the local stack** (wrangler dev + a Pages-like server) with Simulator A, same account:
  - QR link approved from the Simulator ✔; recovery-key unlock ✔; trusted browser reopens without unlocking ✔;
  - edit on the Simulator → web in about 1–3 s ✔; new entry with a photo on the web → Simulator in 1.2 s ✔;
  - an iPhone photo's full rendition (1600 × 1200 JPEG) opens in Brave ✔; trash on the web → the Simulator's Recently Deleted ✔; restore → back on the Simulator ✔;
  - delete account from the web (email re-auth, DELETE) → 0 rows in every D1 table, 0 R2 objects, 1 hashed `deletions_log` row ✔.
- **Lighthouse** on `/app` sign-in (Brave): phone 99 / 100 / 100 and desktop 100 / 100 / 100 (performance / accessibility / best practices), light and dark.
- Production smoke test after deploy: health, session probe, Turnstile enforced, one CSP on `/app` with Turnstile allowed, the real Turnstile widget renders with the site key.

**Security:** gitleaks clean on every commit. /vibesec on `/web` (DECISIONS 199), all findings fixed:
1. Delete account now runs on its own page that never unlocks the diary, because its email re-auth loads Turnstile's script.
2. The page reloads after sign-in, so that script never shares a page with your diary.
3. Duplicate used `fetch(blob:)`, which the CSP blocks.
4. A recovery key copied on the web is now cleared from the clipboard after 2 minutes.
5. A failed email send reused a spent Turnstile token.

No raw-HTML rendering anywhere, no secrets or source maps in the bundle, no open redirects, CSRF covered by SameSite + the Origin check.

**Deviations from SPEC:**
1. Lighthouse SEO is 63 on `/app` by design: the page is kept out of search engines (robots.txt + noindex), and that is the audit that fails. Every other category is 99–100.
2. Not on the web: drafts (content stays in memory only, so the composer asks before discarding); picking category symbols (there are no SF Symbols on the web; existing ones are kept); Share, replaced by "Copy text".
3. Synced display/full photos are JPEG instead of HEIC, so browsers can show them (about 30% more photo storage).
4. A second short-lived cookie, `__Host-folio_oauth`, exists only during an Apple/Google sign-in (10 minutes, deleted on return). It is strictly necessary, so still no banner.

## Part 4 — TestFlight and deploy

**Built:**
- **API deployed** with your OK: migration 0002 applied to `folio-db`, and Worker `folio-api` version `236d92ae-694b-4f15-995c-a6d237e76f11`.
- **Website and web app:** your Cloudflare Pages project `folio` builds every push to main, so https://folio.devilsense.com/app is live.
- **TestFlight 0.1.0 (49)** archived and uploaded from this Mac with `scripts/testflight.sh` after CI went green (c079969); no tag pushed, Xcode Cloud untouched.

### Your checklist — iPhone + Brave on your Mac (one action per line)
1. On your iPhone, install 0.1.0 (49) from TestFlight when it says "Ready to Test".
2. Profile → Continue with Apple → your Apple Account.
3. Check the recovery key now sits on two even lines; Save → Files, type its last 4 characters → Continue, and wait for "You're all set".
4. Profile → Devices: your iPhone shows its model and iOS version. Tap it, type a name, Save.
5. On your Mac, open Brave and go to https://folio.devilsense.com, then click "Open web app".
6. Click "Continue with Apple" and sign in with the same Apple Account.
7. If you want this Mac to open the diary without your iPhone next time, tick "Trust this browser for 30 days".
8. On your iPhone: Profile → Link a browser or device → point the camera at the QR code in Brave → Allow → Face ID. Brave opens your diary.
9. In Brave, write an entry with a photo and Save; check it appears on your iPhone within a few seconds.
10. On your iPhone, change that entry's title; watch it change in Brave.
11. In Brave, tick a task in To-do; it stays 1.2 s, then moves to Completed with an Undo.
12. In Brave, delete an entry; on your iPhone check Profile → Recently Deleted, then restore it in Brave.
13. In Brave, open Profile → Devices: "Brave on macOS" is marked "This device".
14. In a Brave private window, open https://folio.devilsense.com/app → Continue with email → tick "Verify you are human" → Send code; check the code email arrives, then close the window.
15. Send me anything that looked or felt wrong, with a screenshot if you can.

**Manual steps needed from the owner:**
1. If "Continue with Apple" in Brave shows an Apple error page: in Apple Developer → Identifiers → Services IDs → `com.devilsense.folio.web` → Sign in with Apple → Configure, add the domain `folio.devilsense.com` and the return URL `https://folio.devilsense.com/api/auth/callback/apple`. I couldn't check this setting from here.
2. Before App Review (Phase 14), replace the temporary review code: `npx wrangler secret put REVIEW_CODE` (from Batch E).

**Open questions for the Architect:** none.

**Known issues:**
1. Apple and Google sign-in on the web, and a real Turnstile solve, were only checked up to the redirect and the widget. Signing in with your accounts is checklist steps 6 and 14.
2. Photos uploaded by build 0.1.0 (43) are HEIC on the server; the web shows their display or thumbnail size instead of full.
3. The web keeps no drafts: closing the tab loses an unsaved entry (the composer asks before you discard one).

**Next phase ready:** yes — Batch G: your test results for this build, then Phase 13 (motion polish).
