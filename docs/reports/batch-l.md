# Batch L report

Batch L = bugs (Part 1) · website overhaul (2) · web app parity + real-time sync (3) · iPad (4) · security audit (5) · privacy, legal and consumer compliance (6) · accessibility (7) · link and content check (8) · independent review (9) · ship (10). Shape per SPEC §18. Decisions 286–__. TestFlight: **__BUILD__**.

Evidence documents: `docs/SECURITY_AUDIT.md`, `docs/COMPLIANCE.md`, `docs/ACCESSIBILITY.md`. Screenshots: `docs/screenshots/batch-l/` (contact sheets `00-*.png`).

---

## Part 1 — Bugs
- **Sign-in splash removed.** The web app's first paint is now the sign-in card itself; buttons are on screen about 150 ms after navigation (local build, Brave). Signed-in browsers see the same card with a small "Opening your diary…" line, never a full-screen logo; the installed PWA keeps a short mark-only launch. (DECISION 286)
- **Orange screenshots replaced:** widgets (new Home Screen shot with the Month and Today widgets, one task ticked) and the web app images (calendar, entry, journal, to-do, year) retaken from the current build.
- **Found while auditing:** "4 to do · 1 pages" plural bugs (widgets, Lock Screen, Year in Pixels, web Year and Recently Deleted); leftover orange on the home page (privacy lock poster, its accent and glow, the day story's night sky); the web shell ignored settings changes from other devices until something else re-rendered (found by the sync matrix, Part 3); iPad layouts stretched to full width (Part 4); several web-app contrast and ARIA problems (Part 7); a stale iPhone Profile screenshot (Part 8).

## Part 2 — Website overhaul
- **Direction:** the hero is a diary page — faint ruling, an Ink margin line, and an ink stroke that draws once under "kept." — with the app's seasonal layer (chosen in the browser by month and region) and the real web app window behind the 3D iPhone. References studied: Calendly, TickTick, Superfocus and three Dribbble concepts (one confident promise, the product shown at once, restraint, thin frame lines).
- **Honesty pass:** removed the made-up personas and the hand-drawn HTML month; added the real calendar with a key to its marks, "Every screen, as it is" (a strip of real screenshots), and "Make it yours" (avatars, looks, seasons, colours). Copy fixes: "a small company in London" → "registered in England and Wales"; "A person reads every message" removed; alt texts that described older screenshots corrected. iPad screenshot added to Features.
- Screens: `docs/screenshots/batch-l/` (home, features, phone widths). (DECISION 290)

## Part 3 — Web app parity and real-time sync
- **Parity with the iPhone:** calendar marks (today outline, selected square, corner task mark), To-do groups (Overdue · Today · Tomorrow · This week · Later · No date) with the iPhone's natural-date quick add (ported and tested with the iPhone's own 45 phrases + edge cases, 57 tests) and a live chip, subtask/reminder/repeat markers, Journal month folds and icon toggles, Ink theme, custom icons, avatars, a first-visit welcome in the onboarding's voice, Recently Deleted, search, mood, On this day, Year in Pixels, invites for the owner.
- **Browser extras:** keyboard shortcuts (N, T, /, ⌘K, 1–4, [ ], G, ⌘↩, Esc, ?), drag photos onto a day or into the composer, export as JSON + photos (zip made in the tab), Export PDF via the browser's print window (A5 book with cover, months, photos and tasks).
- **Real-time sync matrix:** `scripts/sync-matrix.mjs` (two browsers, Playwright) + the DEBUG-only `SyncProbe` in the iPhone app (scripted edits, millisecond log). **Found and fixed:** the web shell's missing subscription (settings from another device), and the probe's first "offline" leaking pushes. Latency tables below. (DECISIONS 288–289)

### Latency — local API (wrangler dev), 2 browsers + iPhone 17 Pro Simulator
| # | Change | From | Seen on (ms from the change) |
|---|---|---|---|
__LOCAL_TABLE__

Web-made changes arrive in ~0.4–0.9 s (the web's 0.4 s push delay + push + the hub's ping + pull); iPhone-made ones in ~2.1–2.4 s (SPEC §10.5's 2 s debounce). Coming back online catches up in ~45 ms; nothing leaks while offline; the later edit wins a conflict everywhere. S1's local number is not meaningful (the avatar was already set by an earlier run; the script now picks a different avatar each run).

__LIVE_SECTION__

## Part 4 — iPad
- 13" and 11" iPad Pro, portrait and landscape, light and dark (`docs/screenshots/batch-l/ipad/`, sheet `00-ipad-sheet.png`); App Store set `docs/appstore/ipad-0*.jpg` (2752 × 2064, no alpha).
- Fixed: full-width stretching (readable centred column for Journal, To-do, Profile, Year; photo wall wider), narrow month column in portrait, Year in Pixels pager showing a slice of the previous year. Added: keyboard shortcuts in the iPadOS menu bar / ⌘ overlay (focused window only), pointer hover on every pressable control, ⌘↩ to save. Split View / Stage Manager sizes: compact widths use the iPhone layout by size class (not drivable from the Simulator tooling here). (DECISION 293)

## Part 5 — Security
`docs/SECURITY_AUDIT.md`: gitleaks clean (history, web bundle, Release binaries); no trackers or third-party SDKs (iOS links Apple frameworks only; web bundles and live network: own origin + Turnstile on the email step); auth, CSRF (403 on a foreign Origin), rate limits, OTP limits, OAuth state/PKCE, invites, deletion; IDOR tests for every id-taking route (new); validation, size limits (413), generic errors; D1 holds only ciphertext (0 plaintext hits in 102 records) and R2 only random-looking bytes (399 objects, 7.98 bits/byte, no image headers); headers on every page; npm audit 0/0; Dependabot 0 open. **Hardening:** API CSP + CORP headers (deployed e3efea83). (DECISION 294)

## Part 6 — Privacy, legal and consumer compliance
`docs/COMPLIANCE.md` (UK/EU GDPR, PECR, India DPDP, COPPA, US state app-store laws, Apple 5.1.1/4.8, Google OAuth; sources; risk register; owner checklist).
- **18+ accounts:** an unticked "I'm 18 or older and agree to the Terms and Privacy Policy" box on iPhone and web; the server refuses to create an account without it (`403 age_required`, before any single-use code is spent) and records `age_confirmed_at` (migration 0004; API deployed 24c3f190). Guest mode stays open to everyone.
- **Declared Age Range:** Texas SB 2420 is in force since 4 June 2026 and Apple says apps must check age through the Declared Age Range API where the law requires it, with no exemption for 4+ apps. It needs a new entitlement, so it's planned for the public-release build (risk R3); not needed for this TestFlight-only distribution today.
- **Pages:** Privacy Policy rewritten from the schema; Terms updated; new Cookies (every item; no banner — all strictly necessary, by evidence), Refunds (free), Acceptable use, Accessibility, Company details — linked in every footer and in Profile → About (iPhone and web). Self-hosted fonts only; Turnstile is the only third party. (DECISIONS 291–292)

## Part 7 — Accessibility
`docs/ACCESSIBILITY.md`: axe-core 0 serious/critical on 64 page states (website 0 issues of any kind); keyboard tab-through with visible focus everywhere; fixes for quiet-text contrast, dark primary buttons, danger text, ARIA grid rows, a hidden h1, the quick-add bar covering rows; iPhone: Xcode accessibility audit on 15 screens at default size and AX5 — __IOS_AUDIT__. (DECISION 295)

## Part 8 — Links and content
`scripts/crawl-site.mjs`: 21 pages, 112 assets, 15 external links, 0 problems; no placeholder text; TestFlight button real, App Store button hidden. Stale iPhone screenshots retaken. (DECISION 296)

## Part 9 — Independent review
__REVIEW__

## Part 10 — Ship
__SHIP__

**Files changed:** __FILES__

**Deviations from SPEC:** none; SPEC updated (§6.1, §6.16, §10.2b, §11.2, §11.3, §14).

**Owner checklist** (from `docs/COMPLIANCE.md` §11):
1. Pay the ICO data protection fee (Tier 1, £52/year or £47 by direct debit) and register.
2. Decide on an EU Article 27 representative (or restricting EU sign-ups) with a lawyer before wider launch.
3. Confirm the Cloudflare and Resend DPAs apply to your accounts and keep copies.
4. Lawyer review of /privacy, /terms, /cookies, /acceptable-use, /refunds and COMPLIANCE.md before the public App Store release.
5. EU DSA trader declaration in App Store Connect at public launch.
6. Check the Google OAuth consent screen (name, logo, homepage, privacy and terms URLs).
7. Before public launch: approve adding the Declared Age Range capability so it can ship.
8. Keep a short breach-response note.
__CODE_ITEM__

**Only you can test**
__ONLY_YOU__

**Known issues:** __KNOWN__

**Next phase ready:** yes.
