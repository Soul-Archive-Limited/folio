# Batch N report — places, Profile redesign, Edit profile, celebrations, web app pass

_11 November 2026. App Store Connect stayed signed out, as asked; everything Apple-account-side is in the final-pass list at the end._

```
PHASE N REPORT
Built:
- Part 1 · Places on entries (SPEC §5, §6.4–6.6, §11.3; DECISIONS 304–306)
  · iPhone: a Place button in the composer (Folio's own pin glyph). The sheet searches any
    place with Apple Maps autocomplete (leaning towards the last place used), offers Current
    location (when-in-use, one fix, asked only the first time it's tapped, after Folio's glass
    explainer; approximate location accepted and named by area), recent places from the diary,
    "Use “…”" for a name of its own, and Remove place. Never added automatically.
  · A photo that carries a location: read before the metadata is stripped, offered as
    "Add <place>?" (Add / Not now), stored only if accepted, once per composer. The stored photo
    never has a location (unit-tested).
  · Stored inside the encrypted entry (schema v6: name, short address, coordinates; validated
    on sync; web parity). Small place line + map snapshot on cards and entry detail; tap → full
    map with Open in Maps. Journal → Places: a clustered map of every page with a place (tap a
    pin → the page, a cluster → zoom) and the places as a list. Search matches place names;
    PDF and JSON export include the place.
  · Web: place by name (recent places as chips), Open in Apple Maps link, Places list in the
    Journal; no third-party map script (a map would need Apple's MapKit JS or a server token —
    DECISIONS 304).
  · Privacy: location purpose string, privacy manifest Precise Location, Privacy Policy
    "Places on entries" (+ Apple Maps as independent controller), COMPLIANCE (minimisation,
    Art 30 row, R16, R17, checklist 13), APPSTORE.md (Location → Precise Location for you).
- Part 2 · Profile redesign (SPEC §6.9; DECISIONS 307): search settings, profile card with
  Edit profile, one row of four stats, nine rows in three groups that each open a page
  (Account & Sync with owner-only Invite a friend · Categories · Appearance · Writing &
  Dictation · Reminders & Notifications · Widgets · Privacy & Security · Your data · Help &
  About). Fits one iPhone 15 Pro screen at default text size (checked on an iPhone 15 Pro
  Simulator). iPad: sidebar + detail. Web: same structure, rows beside the page from 768 px.
- Part 3 · Edit profile (DECISIONS 308): one sheet — large picture, Choose photo / Folio
  avatars / Remove photo, name, Save / Cancel; one settings write, synced. Web: the same, with
  an in-browser square crop to a 256 px JPEG.
- Part 4 · Gentle celebrations (SPEC §6.22; DECISIONS 309): first page kept for a day → a soft
  Ink bloom on that day + light haptic + "Today's page is kept." (past day: "Kept on …" and a
  page-settling motion); a day's last task ticked → the ring fills with a small sparkle. Under
  a second, interruptible, Reduce Motion = fade, never for synced changes, no streaks or
  counters. Appearance → Celebrations (default on). Matching CSS on the web.
- Part 5 · Web app pass (DECISIONS 310): Playwright suite in e2e/ and in CI (e2e.yml) against a
  local stack — every screen × desktop/phone/iPad × light/dark with zero console errors or
  warnings and axe 0 serious; flows for unlock (wrong and right recovery key), entries + Undo +
  Recently Deleted, natural-language quick add, search by text and place, places, mood, Year
  in Pixels, invites, PDF, theme switch, keyboard only, Profile, Edit profile, celebrations.
  Fixes it led to: month title accessible name, Year in Pixels target size, Places list
  contrast in dark mode, shortcuts during a closing sheet, iPad-width Profile columns, the
  unlock screen remembering the last method (no device-link request each visit), map links in
  normal case. Lighthouse /app: mobile 98 / 100 / 100, desktop 100 / 100 / 100 (SEO 63 by
  design — /app is noindex).
- Part 6 · Test and ship: sync matrix, /vibesec, Release 0 warnings, screenshot-review fixes
  (composer tool row fitting every iPhone, Place sheet surface — DECISIONS 311), TestFlight.

Files changed: ~95. New: ios/Folio/Models/Place.swift, FolioSchemaV5Models.swift,
  Services/Places/{PlaceResolver,PlaceSearch,LocationOnce}.swift, Features/Place/*,
  Features/Composer/ComposerPlace.swift, Features/EntryDetail/EntryPlaceCard.swift,
  Features/Journal/JournalPlacesView.swift, Features/Profile/{ProfilePage,ProfilePageView,
  EditProfileSheet}.swift, Features/Celebrations/Celebration.swift; web/src/app/lib/{place,
  profile-search}.ts, ui/{Place,celebrate}.tsx/ts, ui/journal/PlacesList.tsx,
  ui/profile/{ProfilePages,EditProfile}.tsx; e2e/*; .github/workflows/e2e.yml.

Screenshots / recordings: docs/screenshots/batch-n/ — 00-contact-sheet.png; iPhone light +
  dark 01–10 (composer place chip, photo offer, Place sheet, entry, day panel, Journal Places,
  Profile, settings search, Appearance, Edit profile); iPad 11–12 (Profile split view,
  Places); web-* (desktop, phone, iPad); rec-place-flow.mp4 (composer → Place → "Tate
  Modern" → save → the page with its map), rec-celebrations.mp4 (bloom, page settle, task
  ring + sparkle).

Tests:
- iOS: 270 unit tests pass (new: PlaceTests 10, ProfileSearchTests 3, CelebrationTests 5,
  v5 → v6 migration). Full unit + UI run on the iPhone 15 Pro Simulator: all pass except one
  onboarding back-swipe wait that timed out once and passes alone on both Simulators (wait
  raised to 10 s). AgeCheckUITests 3/3. Release build: 0 warnings.
- API 95/95 (unchanged). Web: 28 build checks + 120 unit tests (new: place, profile search).
- e2e: 244 passed, 0 failed (24 skipped by design) locally; CI "Web app end to end" green.
- Sync matrix (local stack; 2 iPhone Simulators + 2 browsers; docs/reports/batch-n-sync-local.json):
  28 rows, 0 missed. New rows: place with coordinates iPhone → web ~2.2 s and → second iPhone
  ~2.2 s; place by name web → everyone ~0.45 s; remove place; Edit profile web → all ~0.45 s;
  day label across zones (second iPhone in Pacific/Pago_Pago keeps 2026-11-11); offline
  both ways; conflict (later edit wins everywhere).

Security: gitleaks clean on every commit. /vibesec on all Batch N changes: no vulnerabilities;
  one hardening change (map snapshot errors log only a code). docs/SECURITY_AUDIT.md §8.

Deviations from SPEC:
1. Web places are by name only — no map or search on the web without a third-party script or
   an Apple Maps server token (needs the developer portal). Documented, DECISIONS 304.
2. In To-do the "day's tasks done" moment is the haptic only; the ring and sparkle are on the
   calendar day (DECISIONS 309).
3. "App icon later" in Appearance: not built, as the brief says.

Manual steps needed from the owner: none this batch (all Apple-account steps wait for the
  final pass, listed below).

Open questions for the Architect:
1. Web place search: proxy Apple's Maps Server API through our Worker (needs a MapKit key from
   the developer portal; keeps the browser free of third parties), or keep name-only?

Known issues:
1. TestFlight build 137 was archived before the composer tool-row fix (the title was clipped on
   iPhones as narrow as 402 pt); build 138 (or the next one) is the one to test — see HANDOFF.
2. Lighthouse SEO on /app is 63 because /app is noindex on purpose.

Next phase ready: yes (final shipping pass).
```

## What changed for you, in short

- **Places:** write a page, tap the pin in the tool row, search or tap Current location. A photo with a location offers its place; nothing is stored unless you say Add. Journal has a fourth view, Places, with a map.
- **Profile** is now one tidy screen of rows (with a search field); each row opens its own page. Edit profile is one sheet for picture and name.
- **Celebrations:** a soft glow on a day when you keep its first page, a small sparkle when a day's tasks are done. Turn them off in Profile → Appearance.
- **Web app:** checked end to end on every screen at three sizes; places by name, the new Profile and Edit profile, celebrations.

## Final shipping pass — everything left (needs App Store Connect / the developer portal)

1. Sign in to App Store Connect; add the newest TestFlight build to the **Friends** group.
2. **App Privacy:** add **Location → Precise Location** (App Functionality, linked to the user, not used for tracking) and publish — before a build with places goes to review (COMPLIANCE R16).
3. **App Review notes:** the 18+ line (text in docs/APPSTORE.md).
4. **Sign in with Apple:** set the server-to-server notification URL `https://folio.devilsense.com/api/auth/apple/notifications` on the App ID.
5. **Declared Age Range:** check the capability is on the App ID; age-rating questionnaire "Age Assurance — Yes".
6. Changelog entry on the website for the age check, places, Profile and celebrations when that build ships.
7. Still open from Batch L: the **live** sync matrix against production (needs the review code in the Keychain), then delete the review account.
8. COMPLIANCE §11 owner checklist (ICO fee, EU representative, DPAs, lawyer review).
