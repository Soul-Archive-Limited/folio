# Batch L report

Batch L = bugs (Part 1) · website overhaul (2) · web app parity + real-time sync (3) · iPad (4) · security audit (5) · privacy, legal and consumer compliance (6) · accessibility (7) · link and content check (8) · independent review (9) · ship (10). Shape per SPEC §18. Decisions 286–298. TestFlight: **0.1.0 (124)**.

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
| E1 | create entry | webA | webB 470 ms · iPhone 482 ms |
| E2 | rename entry | iPhone | webA 2316 ms · webB 2318 ms |
| E3 | delete entry (to Recently Deleted) | webB | webA 716 ms · iPhone 683 ms |
| E4 | restore entry | iPhone | webA 2104 ms · webB 2106 ms |
| E5 | set mood (Good) | webA | webB 529 ms · iPhone 499 ms |
| P1 | add photo (encrypted upload, 3 renditions) | iPhone | webA 2354 ms · webB 2408 ms |
| P2 | replace photo | iPhone | webA 2395 ms |
| P3 | remove photo | webB | webA 492 ms · iPhone 466 ms |
| P4 | add photo from the web | webA | webB 882 ms · iPhone 866 ms |
| T1 | create task (quick add "today") | webA | webB 443 ms · iPhone 426 ms |
| T2 | tick task | iPhone | webA 2313 ms · webB 2314 ms |
| T3 | untick task (in Completed) | webB | webA 455 ms · iPhone 422 ms |
| T4 | add subtask | iPhone | webA 2273 ms · webB 2277 ms |
| T5 | tick a daily repeating task → next one appears | iPhone | webA 2192 ms · webB 2194 ms |
| T6 | tick on the web (1.2 s rule) — repeat spawns once | webA | iPhone 421 ms · webB 648 ms |
| C1 | create category | iPhone | webA 2237 ms · webB 2238 ms |
| C2 | rename category | iPhone | webA 2106 ms · webB 2108 ms |
| S1 | profile picture (Folio avatar 7) | iPhone | webA 1 ms · webB 2 ms |
| S2 | display name | iPhone | webA 2270 ms · webB 2313 ms |
| S3 | theme → Dark | webA | webB 455 ms · iPhone 420 ms |
| O1 | webB offline 5 s while webA writes; then online | webA | webB after online 42 ms · iPhone 1338 ms |
| O2 | iPhone offline (sync paused) writes; then online | iPhone | webA after online 42 ms · webB after online 45 ms |
| X1 | conflict: web edits, then iPhone edits offline → later wins | both | webA 250 ms · webB 259 ms · iPhone pushed 223 ms |

Web-made changes arrive in ~0.4–0.9 s (the web's 0.4 s push delay + push + the hub's ping + pull); iPhone-made ones in ~2.1–2.4 s (SPEC §10.5's 2 s debounce). Coming back online catches up in ~45 ms; nothing leaks while offline; the later edit wins a conflict everywhere. S1's local number is not meaningful (the avatar was already set by an earlier run; the script now picks a different avatar each run).

### Latency — live API: not run yet
The live run needs the App Review account's code, which is a Worker secret this session doesn't have; it was requested at the start of the batch (store it in your Keychain with `security add-generic-password -a folio -s folio-review-code -w`). Everything else is ready: the same script and probe run unchanged against production (`--web https://folio.devilsense.com --api https://folio.devilsense.com/api/`), then the review account is deleted to prove the production wipe. Exact steps are in `docs/HANDOFF.md`.

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
`docs/ACCESSIBILITY.md`: axe-core 0 serious/critical on 64 page states (website 0 issues of any kind); keyboard tab-through with visible focus everywhere; fixes for quiet-text contrast, dark primary buttons, danger text, ARIA grid rows, a hidden h1, the quick-add bar covering rows; iPhone: Xcode accessibility audit on 15 screens at default size and AX5 — fixed the disabled Apple button's missing trait (buttons now point at the 18+ box instead), made the box a real toggle with reachable Terms/Privacy links, moved the marks-key action off the 17-pt weekday strip; accepted with reasons: Liquid Glass contrast/clipping (DECISIONS 211), iOS 26's partial Dynamic Type on system toolbar items, Year in Pixels squares, the system clear button; **open for a device check:** one unresolvable too-small target on the calendar and one undescribed element in search. (DECISION 295)

## Part 8 — Links and content
`scripts/crawl-site.mjs`: 21 pages, 112 assets, 15 external links, 0 problems; no placeholder text; TestFlight button real, App Store button hidden. Stale iPhone screenshots retaken. (DECISION 296)

## Part 9 — Independent review
A separate agent with none of this batch's context reviewed SPEC, COMPLIANCE, SECURITY_AUDIT and ACCESSIBILITY against the code and the live site (read-only). **15 confirmed findings — all fixed or documented:**
1. Request-level Workers logs and traces were on (URLs, metadata) while the docs said no IPs at rest → invocation logs and traces turned off; only our structured events remain; disclosed.
2. Google `profile` / Apple web `name` requested but never used, and the policy said we only receive id + email → scopes now `openid email` / `email`.
3. Email-code guessing across networks (~1,440 tries/day/address) and Turnstile skippable via `client: ios` → 20 checks and 10 codes per address per day, any network.
4. Retention wording shorter than the nightly clean-up → corrected ("deleted when used or at the nightly clean-up"; counters up to three days).
5. Email rate-limit key was a plain SHA-256 (reversible by guessing) and per-account counters undisclosed → HMAC keys; disclosed.
6. Web export silently skipped photos it couldn't fetch → counts and warns.
7. iPhone: Terms/Privacy links unreachable by VoiceOver inside the consent button → separate links; real Toggle.
8. "One cookie" vs the two listed → consistent wording.
9. Encrypted photos cached for a year in the browser → `no-store`.
10. Existing accounts never shown the new terms → owner checklist item; misleading code comment fixed.
11. Remote sign-out left the trusted-browser key → every sign-out path forgets it and Folio's local items (theme kept).
12. Policy gaps (iCloud Keychain, deletion tombstones, Resend logs, localStorage after sign-out) → added.
13. Turnstile hostname/action not checked → checked.
14. Accessibility statement claimed a web screen-reader pass → reworded to what was done.
15. Purpose text omitted account emails; no security.txt → fixed; `/.well-known/security.txt` added.
**For a human (in COMPLIANCE.md):** Turnstile controller role (R11), Resend log retention (R12), dated legal facts and the DUAA exception (checklist 12), an Art 30 record (added), age-rating questionnaire (checklist 10), Sign in with Apple server notifications (R13), whether COMPLIANCE.md should be public (checklist 11), and a reauth edge case (fixed: re-authentication needs a live session). API deployed 5499d15a. (DECISION 297)
Also found while shipping: Cloudflare's Email Obfuscation was rewriting our mailto links and injecting a script on production → switched off with `<!--email_off-->` markers (DECISION 298).

## Part 10 — Ship
- **Tests:** iOS 248 unit + 19 crypto pass; UI tests changed this batch pass locally (onboarding consent flow; the long-press test no longer races its toast); iOS accessibility audit as in Part 7; API **87/87**; web **114** unit + **28** build checks; axe 0 serious; crawler 0 problems (production: one problem found and fixed, DECISION 298).
- **Release build:** 0 warnings, 0 errors. **CI:** green on 6a49a5c (iOS, API & web, secret scan); docs-only commits after it pass the secret scan.
- **API:** deployed 24c3f190 → e3efea83 → **5499d15a** (migration 0004 applied). **Website:** live on Cloudflare Pages from main.
- **TestFlight:** **0.1.0 (124)** uploaded 6 November 2026 (archive + upload from this Mac; App Store Connect is processing it). **Not yet in Friends:** App Store Connect wasn't signed in in the browser pane, so the owner adds it (TestFlight → 0.1.0 (124) → Groups → Friends) and pastes the 18+ line into the App Review notes.

**Files changed:** ~190 files (`git diff --stat edfc301`). Key: `web/src/components/home/*`, `web/src/pages/{privacy,terms,cookies,refunds,acceptable-use,accessibility,imprint}.astro`, `web/src/app/{lib/{quickadd,export,zip,task-groups}.ts,ui/{Welcome,Help,AppRoot,SignIn,Shell}.tsx,ui/profile/PrintBook.tsx}`, `api/src/{routes/auth.ts,auth/*,index.ts}`, `api/migrations/0004_age_confirmed.sql`, `api/test/{age,idor,review-fixes}.test.ts`, `ios/Folio/{App/FolioCommands.swift,Services/Sync/SyncProbe.swift,Features/Account/SyncSignInButtons.swift,DesignSystem/Components/ReadableWidth.swift}`, `scripts/{sync-matrix.mjs,crawl-site.mjs,ipad-shots.sh}`.

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
9. Tell your friend the Terms changed (18+ accounts, Acceptable Use) — the only other account.
10. Re-check the age-rating answers when the Declared Age Range check ships; decide whether COMPLIANCE.md stays public; have the lawyer confirm the dated legal facts.
11. **For this batch:** store the review code in your Keychain (command above) so the live sync test can run; sign in to App Store Connect in the browser pane so the build can be added to Friends — or add it yourself (TestFlight → 0.1.0 (124) → Friends) and update the App Review notes with the 18+ line from `docs/APPSTORE.md`.

**Only you can test**
1. On build 124: sign in on a fresh install — the 18+ box, then Apple / Google / email; check that tapping a button before ticking points at the box.
2. Web app in your browser (Safari and Brave): sign-in opens instantly; the welcome appears once; drop a photo on a day; press ? for shortcuts; Profile → Export PDF prints a book.
3. iPad (if you have one): the sidebar, ⌘N / ⌘1–4 with a keyboard, pointer highlights.
4. VoiceOver on a device: the calendar (one audit item couldn't be resolved in the Simulator) and search.

**Known issues:** 1. Live sync latency not measured on production (review code needed) — local results above.
2. Two iPhone accessibility audit items without a resolvable element (calendar target, search description) need a device check.
3. Declared Age Range (Texas SB 2420) and Sign in with Apple server notifications are planned for the public-release build.
4. Split View / Stage Manager sizes on iPad weren't driven from the Simulator; compact windows use the iPhone layout.

**Next phase ready:** yes.
