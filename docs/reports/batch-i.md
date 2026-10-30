# Batch I report

Batch I = every fix from your iPhone test of 0.1.0 (56) (Part 1) · profile pictures and Folio avatars (Part 2) · a researched, redesigned onboarding (Part 3) · seasonal backgrounds (Part 4) · reminders, repeating tasks and subtasks (Part 5) · my own test run of your checklist on Simulators (Part 6) · ship (Part 7). Shape per SPEC §18, one section per part. Contact sheet: `docs/screenshots/batch-i/00-contact-sheet.png`. Decisions 224–252.

---

## Part 1 — Fixes from your test

**Built** (root cause first, each with a test where one is possible):
1. **Theme / writing font / first day of week didn't apply** — `DiaryStore.settings()` was the only read that didn't observe the store, so nothing redrew. Fixed, plus the theme is set on every window (sheets included). New: the three settings on Folio's page in the iPhone Settings app, kept in sync both ways (`SystemSettingsBridge`). Web already applied them live.
2. **Onboarding stuck between pages on a back swipe** — the old pager resized under the keyboard mid-swipe. Replaced in Part 3 by a step stack using the system back swipe.
3. **Tour rings** — measured in each host's own coordinate space (the composer sheet moves while presenting), even 6 pt padding, concentric corners; tab rings measured from the live tab bar. Step 4 verified by a new UI test.
4. **Calendar half-collapsed / jank** — Time Profiler (same scripted drags, 10,000 entries): the month grid re-ran on every drag frame, mostly a SwiftData category fetch (26 → 0 main-thread samples). Only three tiny modifiers read the drag now; a stop between the ends settles to the nearer end. Recording: `rec-calendar-drag.mp4`.
5. **Blank calendar after discarding an edit** — the sheet was dismissed from inside the dialog's action; it now closes once the dialog has gone.
6. "Discard changes?" / "Keep editing" for saved entries.
7. **Checklists** — tap a box to tick/untick; Return continues; Return on an empty item ends it (web's Tiptap boxes already toggle on click).
8. **Share** — text is a plain `String` (WhatsApp's Next now enables); image: one card, or "Single card" / "All pages (N)" story images (1080 × 1920, numbered, nothing cut).
9. **Composer as a layer** — dimmed calendar behind, stronger material, fine top highlight, light and dark.
10. **"+" area** — nothing full-width behind the button; the day panel scrolls fully clear of it.
11. **Markers** — one place per meaning (today = ember number + outline; dots = pages; corner ring/check = tasks; "+2" bottom-right); "What do the marks mean?" in Profile → Help and on a long-press of the weekdays.
12. App-switcher cover — eight lines, a new one each time, never the last one.
13. Journal — lighter month headers; months fold (this and last open), remembered.
14. To-do — scroll/tap dismisses the keyboard; tap a task to edit (long-press keeps the menu); drag to reorder within a date.
15. **Quick add** — natural dates and times with a live chip; 45 phrases + 7 must-stay-as-typed lines tested (en-GB/en-IN day-first, en-US month-first).
16–18. Recently Deleted button in ember · "On this day" with "You wrote on 29 October in 2025" · "Continue your draft" pill after a full close (tap to resume, swipe to discard).
19. Compact headers — smaller titles that become a slim glass pill on scroll; "Past day" and the To-do date filter moved to the top bar (fewer pills).
20. Dictation — your region's English (en-IN, en-GB…), punctuation + frequent finalisation, contextual hints (name, categories, title), elapsed time in the capsule, on-device "Tidy punctuation and capitals?" after Done (applied only if every word is unchanged). 30-minute cap and 2-minute silence stop kept.
21. Smoothness — besides 4: Profile spent **~1.8 s** of main-thread time loading every entry and photo for its numbers; now counts in the database, cached, computed off the main thread. Journal's Photos list cached.

**Screenshots:** `before/b01–b10`, `after/a01–a10` (light + dark), `after/a04-tour-step4.png`.

## Part 2 — Profile pictures and Folio avatars

- Tap the avatar → **Choose photo** (PhotosPicker + circular crop: drag, pinch) or **Folio avatars** · Remove picture.
- **24 original "page spirits"**: a little page with a folded corner, a face and the ember dot, each with its own palette and personality; vector SVG, light and dark. Three directions were drawn first (`avatars/01-style-directions.png`); I chose A, "Page spirits" — the most unmistakably Folio and the most character at small sizes (DECISION 238). The set: `avatars/02-set-light.png`, `02-set-dark.png`.
- Syncs encrypted with the settings; shows in Profile, the greeting, Devices and the web app (sidebar, Profile — where you can also pick a Folio avatar — and Devices). Schema v4.
- Screenshots: `avatars/03–07`.

## Part 3 — Onboarding

- **Research:** `docs/ONBOARDING.md` — Day One, Structured, Flighty, Stoic, Opal, Apple Journal and Apple's first-run screens (from my knowledge of their public flows, not a fresh hands-on run this session).
- **New flow:** Your days, kept → **Start with today** (write a line or pick a photo and watch it fly into today's square — a real entry) → What will you keep here? (makes categories) → name + avatar → your look (live theme, season effect) → sync with **Not now** → greeting → tour. Thin progress bar, system back swipe on every step, no keyboard carried between steps, Reduce Motion fades.
- Found while testing: interactive glass around the line field swallowed the tap, so typing reached the focused button (a stray "Not now"). Fixed (DECISION 244).
- `OnboardingUITests` walks every step including a back swipe. Recording: `rec-onboarding.mp4` (450 KB). Screenshots: `onboarding/step0–5` light + dark.

## Part 4 — Seasonal backgrounds

- Blossom (spring), warm glow (summer), rain (monsoon), leaves (autumn), snow (winter): about a dozen tiny shapes at low opacity, top third only, behind everything.
- Season from the month + the iPhone's region (no location); table in SPEC §3.5 (temperate north, flipped south, Indian subcontinent, two tropical patterns).
- Profile → Appearance → Season effect: Auto / a season / Off. Off with Reduce Motion, Low Power Mode, in the background.
- CPU (Simulator, idle on the calendar): off 5.4 %, summer 5.5 %, monsoon 5.8 %, winter 6.1 % — **≤ 0.7 points**. Screenshots: `seasons/`.

## Part 5 — Smarter tasks

- **Remind me** at the task's time or a chosen time: local notifications only; glass explainer before the first system prompt; actions **Done**, **Snooze 1 hour**, **Tomorrow**. The reminder syncs; each device schedules its own in its own time zone.
- **Repeat**: every day / weekday / week / month / year / custom (every N days, weeks, months). Ticking keeps the task done on its day and adds the next one, once. Same rule on the web (shared test cases).
- **Subtasks**: tick in place, add with Return; "1/3" on the row; deleted and restored with the parent.
- **Groups**: Overdue · Today · Tomorrow · This week · Later · No date, folding and remembered, plus a date filter in the top bar.
- Screenshots: `tasks/`.

## Part 6 — What I tested myself

Local API (`wrangler dev`, throwaway data) with two Simulators, plus a live smoke check. Screenshots in `part6/`.

| Case | Result |
|---|---|
| New account, recovery key, first upload of a guest diary | ✅ |
| Link a second device by QR (approve on the first) | ✅ |
| Edit on A → appears on B | ✅ ~1.2 s |
| Airplane mode: edit offline → "Offline" → pushes on reconnect | ✅ |
| Conflict: both edit the same entry offline | ✅ the later edit wins on both |
| Trash on B → A's Recently Deleted; restore on A → back on B | ✅ |
| 10 photos + a ~50,000-character entry, app sent to background mid-upload | ✅ 105 encrypted blobs = 35 photos × 3 |
| Time-zone change (UTC−11) | ❌→✅ **found and fixed**: day labels showed the previous day west of UTC (DECISION 249) |
| Restart | ✅ still signed in, up to date |
| Sign out / in with the recovery key on a reset device | ✅ |
| Delete account → D1 and R2 empty | ✅ all rows 0 (one hashed deletion-log line); every R2 object of the account gone |
| The other device after deletion | ❌→✅ **found and fixed**: kept showing "Up to date"; now signs out to guest, diary kept (DECISION 250) |
| Web app: sign in, unlock with recovery key, avatar from iPhone, subtasks under parent, repeat on tick | ✅ |
| Live: site, `/app`, API health, avatars served | ✅ 200 |
| Low Power Mode | ⚠️ the Simulator can't turn it on; the observer is in place |

Not run: weak-network shaping (no Network Link Conditioner on this Mac); unreachable-API failures stood in for it.

### Only you can test
1. Face ID before the recovery key and when approving a link.
2. Scanning the QR with the real camera.
3. Sign in with Apple on your iPhone (and in a desktop browser).
4. Dictation accuracy in your voice — en-IN/en-GB variant, hints, Tidy.
5. Reminders on the lock screen: Done, Snooze 1 hour, Tomorrow; on two devices.
6. Haptics.
7. How it feels: calendar drag, month paging, onboarding back swipe, season effect at 120 Hz.
8. Instruments' Animation Hitches on your iPhone (it needs a device; see below).

## Part 7 — Ship

- **/vibesec** on everything touched: two fixes (bounded synced repeat rules; live reconnect only while signed in), rest clean — DECISION 252. `npm audit` 0, gitleaks clean on every commit.
- **Release build:** 0 warnings. **Tests:** iOS 212 unit + 19 crypto + UI tests (32 incl. new onboarding and tour tests) pass locally; web 47 unit + 22 build checks; CI status in the closing note.
- **TestFlight link:** still "This beta isn't accepting any new testers right now" — build 56 isn't approved yet, so `testflightUrl` stays empty.
- **Upload — blocked:** 0.1.0 (74) archived (`ios/build/testflight/Folio.xcarchive`, from the CI-green commit), but the upload stopped with `exportArchive Failed to Use Accounts`: Xcode's Apple Account session on this Mac has expired, and App Store Connect in the browser is signed out. Both need your password, so the build isn't in TestFlight or the Friends group yet.

**Files changed:** ~150 (`git diff --stat 379ff36`). Key: `ios/Folio/Features/{Onboarding,Avatar,Todo,Calendar,Composer,Share,Journal,Profile,Tour,Dictation}/*`, `Models/{RepeatRule,FolioSchema*,TaskItem,UserSettings}.swift`, `Services/{Reminders,Settings,Store,Sync}/*`, `DesignSystem/Background/{Season,SeasonalLayer}.swift`, `Resources/Settings.bundle`, `scripts/avatars/*`, `shared/avatars/*`, `web/src/app/{lib/repeat.ts,ui/Avatar.tsx}`, `docs/{ONBOARDING,SPEC,DECISIONS,HANDOFF}.md`.

**Deviations from SPEC:** none left; SPEC updated for every behaviour change (§2, §3.1, §3.2, §3.5, §4.3, §5, §6.1–6.9, §7, §8, §17).

**Manual steps needed from the owner:**
1. Xcode → Settings → Accounts → sign in again with the Apple Account for team Soul Archive Ltd, then tell me "continue" (I'll rerun `scripts/testflight.sh`, add the build to Friends and submit it for review if Apple asks). Or upload the archive yourself from Xcode → Window → Organizer.
2. Check the Beta App Review result for build 56; once approved, tell me (or put `https://testflight.apple.com/join/88BuzSRc` in `web/src/config/site.ts` → `testflightUrl`).
3. Run the "Only you can test" list on the new build.

**Open questions for the Architect:**
1. For the device Instruments run: may I install a development build on your iPhone (it replaces the TestFlight install), or would you rather run Animation Hitches yourself from Xcode?

**Known issues:**
1. An older app version that edits a task or the settings drops the new fields (reminder, repeat, subtasks, avatar) — testers should update (DECISION 240).
2. Editing reminders, repeats and subtasks is iPhone-only for now; the web keeps them and repeats on tick.
3. 120 fps not verified on a device.

**Next phase ready:** yes.
