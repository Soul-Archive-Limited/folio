# Batch J report

Batch J = your notes on 0.1.0 (74) (Part 1) · search (2) · Lock Folio (3) · widgets, controls and Siri (4) · memories (5) · bringing things in (6) · PDF export (7) · private accounts and the installable web app (8) · test, ship, document (9). Shape per SPEC §18, one section per part. Contact sheet: `docs/screenshots/batch-j/00-contact-sheet.png`. Decisions 255–272. TestFlight: **0.1.0 (94)**.

---

## Part 1 — Your findings on 0.1.0 (74)
You said "all good" — nothing to fix.

## Part 2 — Search
- **Built:** one search field in three places — Calendar (pull the day panel down: "Pull to search" → "Release to search", or the magnifier), Journal and To-do (the native pull-down drawer; To-do searches tasks and subtasks only). Titles, text, category names, tasks, notes and subtasks; filters for category, photos, dates (presets or Choose dates…) and open/done. Matches are highlighted (ember wash + bold); page snippets start just before the match; results open in place (Back returns to them).
- **On the device only:** an in-memory index built off the main thread, re-built in the background after writes while a search is open (changed pages only). A query on **10,000 entries takes a few milliseconds** (test). Accents fold for Latin letters, Hindi words stay whole, Chinese/Japanese characters count one per word.
- **Web:** the same search in the tab's memory — Search in the sidebar and tab bar, "/" or ⌘K. Both platforms pass the same word fixtures (`shared/search-fixtures.json`).
- Screenshots: `p2-calendar-search-light`, `p2-journal-search-dark`, `p2-todo-search-light`, `p2-web-search`. Recording: `rec-search.mp4`.

## Part 3 — Lock Folio
- Profile → Privacy & Security → **Lock Folio** (Face ID / Touch ID / passcode) and **Lock: immediately / 1 / 5 / 15 min**. Turning it on or off asks for Face ID first.
- The lock is its **own window above everything**, in every window on iPad: sheets, menus, links from widgets and shortcuts all open underneath it. It goes up the instant Folio leaves the screen, so the app switcher shows the cover; on cold launch you see the launch screen until the lock is up. Locked: mark + greeting at the top, Face ID asked at once, "Unlock with Face ID" at the bottom.
- **Found and fixed while testing:** coming back from the Face ID sheet re-locked straight away.
- Tested on the Simulator with simulated Face ID (match / no match), including the composer left open → Home → back: the lock covered the sheet in the first frame. Screenshot: `p3-lock-faceid-light`.

## Part 4 — Widgets, controls, Siri
- **Home Screen:** Today (date, greeting, next tasks with a **tick that works on the widget**), Month (photo tiles, dots, task marks; each day opens it), Quick add (page / task / dictate). **Lock Screen:** next task and today's count — counts only unless you turn details on. **Control Center / Action Button:** New Entry, Dictate, Add Task. **Siri & Shortcuts:** Add Task (with a date and time, without opening Folio), New Entry, Dictate Entry, Show Today, Open On This Day.
- **Privacy:** widgets read a small snapshot on the iPhone (App Group, readable after first unlock), never the diary itself, and it never syncs. Profile → Widgets: "Show details on Home Screen" (on) / "on Lock Screen" (off). Titles and photo tiles are privacy-sensitive, so a locked phone redacts them.
- A tick on a widget is queued and shows at once; Folio applies it when it next runs (a normal edit that syncs).
- Tested: widgets added on the Simulator, a tick → queued → applied when Folio opened; `folio://` links. Screenshot `p4-widgets-home-light`; recording `rec-widget-tick.mp4`.

## Part 5 — Memories
- **Mood** (optional, five steps: Heavy · Low · Steady · Good · Bright) — our own mark, a ring that fills from the bottom, never a face. Set from the composer's tool row; synced end-to-end encrypted (schema v5); shown on cards, in the entry, and on the web.
- **On this day:** a card at the top of the day panel (iPhone and web), plus an **opt-in morning notification** (Profile → Memories, time of your choice) that names only the year.
- **Year in Pixels:** the Journal's third view on iPhone and web — every day a square, by mood or category, years swipe, tap opens the day. No streaks.
- Tested: mood set on the iPhone appeared in the web's Year view after sync. Screenshots: `p5-year-in-pixels-light/dark`, `p5-day-onthisday-light`, `p5-web-year-in-pixels`, `p5-web-calendar-onthisday`.

## Part 6 — Bring things in
- **Scan paper pages** ("+" long-press → Scan a paper page): document camera or photos of pages → text read on the iPhone → the **date found on the page is suggested** → a new entry with the scans as photos and the text to correct. Multi-page (10 photos per entry; text from every page kept).
  - Hindi: Apple's text recognition on **iOS 26.5 has no Hindi** (the newer macOS does), so Hindi lines are unreadable there today; lines it isn't sure of are dropped and the scan photo always keeps the page.
- **Share into Folio:** photos (up to 10), text and links from any app → a small composer (title, a line, day, "Add to that day's page", category) → saved **encrypted** on the iPhone (Keychain key shared through the App Group) → Folio imports it when it next opens.
- **Apple Calendar** (opt-in, read-only): today's events in the day panel and a small bar on days with events; never stored in Folio or synced.
- Tested: OCR and date on a rendered sample page (test), save → entry on 12 Mar 2019; Photos → Share → Folio → Save → imported (UI test); calendar events seeded on the Simulator. Screenshots: `p6-scan-review-light`, `p6-share-composer`, `p6-calendar-events-light`. Recording `rec-scan.mp4`.

## Part 7 — PDF export
- Profile → Your data → **Export PDF**: dates (+ quick ranges), photos and tasks on/off → made on the iPhone in the background with progress → preview → **Share** or **Print**.
- The book: A5, cover (picture, "Sam's diary", range, page count), each month opens a new page with a large heading, entries with date line, mood, title, formatting and photos, tasks if chosen, page footers.
- **Three years of the sample diary: 38 pages in about 3 s** (test). Sample PDF: `docs/screenshots/batch-j/p7-sample-3-years.pdf`; pages `p7-pdf-pages.png`; recording `rec-pdf.mp4`.

## Part 8 — Private accounts
- **Invite-only sign-up:** new accounts need a one-time code (`ABCD-EFGH`, 7 days, single use). Existing accounts, your owner addresses and the App Review account are unaffected; guest mode needs nothing. The code is asked for **only when a sign-in would create an account**, and nothing single-use is wasted (the email code stays valid while you type the invite; Apple's code isn't spent).
- **Owner:** Profile → **Invite a friend** on iPhone and web — make a code (shown once, with Share), see your invites, revoke unused ones. Codes are stored only as a hash.
- **Tested end to end** on two Simulators against the local API: owner made `Z76M-2K4C` → a new email account was asked for an invite → entered it → account created, invite marked used. 69 API tests including expiry, revoke, single use and owner-only access. Screenshots: `p8-invites-owner-light`, `p8-invite-asked-light`, `p8-web-invites`.
- **Installable web app:** manifest, icons, standalone, and a service worker that caches **only the app shell** (never `/api`); offline it opens to the "You're offline" screen. "Install on your phone" in the web Profile and on the Download page. Screenshots `p8-pwa-offline`, `p8-web-install`.

## Part 9 — Test, ship, document
- **Tests:** iOS 244 unit + 19 crypto + UI suite pass; API 69; web 51 unit + 23 build checks. Release build **0 warnings** (with both new extensions).
- **My own run:** two Simulators + web against the local API, a time-zone check in UTC−11 (search dates and the day panel unchanged) (owner signs in, links the browser by QR, makes an invite; a new account uses it; moods and search on the web), offline (search, PDF, scan and widgets work with no network; the installed web app opens offline), lock/unlock, widgets on the Simulator, share extension (UI test), scan with a sample image, PDF of a 3-year range.
- **/vibesec:** access control, enumeration, CSRF, redirects, rate limits, extension inputs, App Group/Keychain, web output and the service worker — no new findings (DECISION 271). `npm audit` 0 in api and web; gitleaks clean on every commit.
- **CI:** green. Fixed on the way: Xcode 26.6 on CI couldn't type-check a long predicate in the PDF code; a recording test read its sample path before checking whether recording was on; the delete-toast UI test needed longer waits on the slower CI runner.
- **Website:** Features gains Find and remember · Bring it in · Around your iPhone with real screenshots; FAQ, Download ("Install on your phone") and Changelog updated.
- **TestFlight:** 0.1.0 (91) and (93) failed App Store Connect's processing — an App Intent description said "iPhone", which Apple doesn't allow (DECISION 274); 93 also added the extensions' privacy manifests (273). **0.1.0 (94)** processed, was added to **Friends** with "What to Test" notes and submitted for Beta App Review, which cleared it at once (status Testing).

**Files changed:** ~140 (`git diff --stat 5dbee75`). Key: `ios/Folio/{Services/Search,Features/Search,Features/Lock,Services/Widgets,App/Intents,Features/Scan,Services/Scan,Services/Calendar,Services/Export/DiaryPDF*,Features/Profile/{PDFExportSheet,InvitesView}}`, `ios/{Shared,FolioWidgets,FolioShare}`, `ios/Folio/Models/{Mood,FolioSchemaV4Models}.swift`, `api/src/{lib/invites,routes/invites}.ts`, `api/migrations/0003_invites.sql`, `web/src/app/{lib/search.ts,lib/install.ts,ui/Search.tsx,ui/Mood.tsx,ui/journal/YearPixels.tsx,ui/profile/{Invites,InstallHelp}.tsx}`, `web/public/{manifest.webmanifest,app-sw.js,icons}`.

**Deviations from SPEC:** none left; SPEC updated for every new behaviour (§4.4, §5, §6.2, §6.4, §6.6, §6.7, §6.9, §6.17–6.21, §7, §10.2a, §10.7, §11.3, §17).

**Manual steps needed from the owner:**
1. Nothing for sign-up: you chose to keep it open (DECISION 276). To go invite-only later, set `INVITES_REQUIRED` to "true" in `api/wrangler.jsonc`, run `npx wrangler secret put OWNER_EMAILS` and `npx wrangler deploy` in `api/`.
2. Install 0.1.0 (94) and run the "Only you can test" list.

**Only you can test**
1. Face ID lock on your iPhone: unlock, Lock after 1 min, a widget or Siri opening a locked Folio.
2. Widgets on your Home and Lock Screen; Control Center buttons; the Action Button; Siri "Add a task in Folio".
3. Scanning a real paper page with the camera (and Hindi, if your iOS has it).
4. Sharing from Photos/Safari/WhatsApp into Folio.
5. Apple Calendar events with your own calendars.
6. The On this day morning notification.
7. Printing a PDF to a real printer.
8. (Later, if you switch invites on) the invite flow on production: make an invite, a friend signs up with it.
9. Installing the web app on your phone.

**Open questions for the Architect:** none.

**Known issues:**
1. A widget tick reaches your other devices only once Folio next runs on that iPhone (widgets can't open the diary — DECISION 260).
2. Hindi scanning needs an iOS version with Apple's Hindi text recognition (not iOS 26.5).
3. Builds before 0.1.0 (94) that edit an entry drop its mood (older apps don't know the field) — testers should update.
4. Sign-up is open by choice; the invite screens appear only once invites are switched on.

**Next phase ready:** yes.
