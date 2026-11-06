# Batch K report

Batch K = fix Google sign-in (Part 1) · invite-only on (2) · day panel duplicates (3) · replaced-photo bug (4) · rebrand: logo, colour, icons (5) · ship (6). Shape per SPEC §18, one section per part. Decisions 278–285. TestFlight: **0.1.0 (107)**.

Sheets: `docs/screenshots/batch-k/` — `00-before-after-light.png`, `00-before-after-dark.png`, `01-logo-directions.png`, `02-logo-chosen.png`, `03-app-icon-appearances.png`, `04-icon-set.png`; raw shots in `before/` and `after/`.

---

## Part 1 — Google sign-in (root cause)
- **Root cause: the `GOOGLE_CLIENT_SECRET` stored in Cloudflare was not the Web client's secret.** Reproduced on the live API with `wrangler tail`: start → callback with a deliberately fake code got **401** from Google's token endpoint (a correct client with a bad code gets 400 `invalid_grant`). With Google's error code now logged it read `invalid_client` — "The provided client secret is invalid." The client ID and redirect URI were right (you reached the account chooser; a wrong redirect URI fails before it); the D1 tables, state/PKCE expiry, the one-time hand-off and email linking were all fine. So every Google sign-in died at the code exchange and the app showed its generic "Sign-in didn't work".
- **Fixed:** you added a new secret (2026-11-06); re-probed live, the same fake code now gets `invalid_grant` — Google accepts Folio's credentials.
- **Hardened:** secrets trimmed (a pasted newline causes the same error); the exchange says *why* it failed; every OAuth failure returns to the app or web app with a specific reason and its own message — "Google sign-in isn't working on our side right now. Please use Apple or email…" (`google_unavailable`), "That sign-in took too long and expired…" (`expired`), "This account is being deleted…", invite needed — never a raw error page inside the sign-in sheet; the state carries its platform so even an expired one returns to the right place.
- **Tests:** 6 new API tests (refused secret, refused code, expired iOS state, a Google email that already has an account links to it with no second user, account being deleted, secret with a newline) + an iOS test for the reason → message mapping. API deployed (0a03bcfe, then 97fa6013 with Part 2).
- **Re-test on the live API:** done from here — start, callback and exchange paths, error reasons, the client credentials. **Not done from here:** a real Apple / Google / email sign-in end to end — that means signing in to an account (Google/Apple passwords, or reading a new inbox), which I can't do. It's item 1 on your test list.

## Part 2 — Invite-only on
- `INVITES_REQUIRED` = "true" in `api/wrangler.jsonc`; `OWNER_EMAILS` = your Apple private-relay address, piped into `wrangler secret put` (never in a file); deployed (97fa6013). Decision 279 replaces 276.
- **Checked live (read-only D1):** your one account (Apple) carries that address → exempt, and `canInvite` is true so **Invite a friend** shows in your Profile; the App Review address is exempt by rule (`REVIEW_ENABLED` true; no account yet). A brand-new email being asked for a code is covered by the invite API tests; seeing it live needs a real new inbox (your test list).

## Part 3 — Day panel duplicates
- The + beside the date is gone; an empty day shows one line: "Nothing written yet. **Add task**" (a text button, 44 pt tall). New pages come only from the floating + (tap = page for that day, long-press = page / task / dictate / scan).
- Web: the same line; the phone-width + gets the same long-press (or right-click) menu; desktop keeps the sidebar's New entry. Decision 280. Screens: `p3-empty-day-light/dark.png`.

## Part 4 — Replaced photo stayed on the card
- **Root cause:** not the caches (already keyed by photo id) but the photo views. `PhotoTile` / `FullPhotoImage` kept their image when SwiftUI reused the card for an entry whose photo had changed, and only loaded when they had no image — so the new photo was never loaded until a restart. Views now remember which photo their image belongs to (`ShownPhoto`): a different photo drops the old image and loads; a late load for a photo the view has left is ignored. That covers the day panel, Journal cards, entry detail and composer; the full-screen viewer and the Month widget were already keyed by photo id.
- **Web:** `PhotoImg` carried its rendition fallback across photos and gave up on a just-synced photo whose bytes hadn't arrived; both fixed (retries 3×).
- Tests: `ShownPhotoTests` (3), `photo-load.test.ts` (2). Decision 281.

## Part 5 — Rebrand
### Logo — three directions (`01-logo-directions.png`)
- **A · Page & nib** — a page with a fountain-pen nib writing on it. Clear, but a generic "document + pen".
- **B · Nib book** — an open diary whose gutter is a fountain-pen nib (slit and breather hole). **Chosen:** symmetric, ownable, and still diary + pen at 32 px; a simpler drawing (no slit, wider gutter) for 16 px (`02-logo-chosen.png`).
- **C · Bookmark nib** — a page whose ribbon bookmark ends in a nib. Reads as a document icon when small.
- Applied everywhere from one generator (`scripts/brand/generate.py`): **app icon as an Icon Composer `.icon` package** (one glass layer; light, dark, tinted and clear checked with `ictool`, `03-app-icon-appearances.png`), launch screen, greeting, app-switcher cover, lock screen, PDF cover, website logo (nav, footer, /app gate), favicon, PWA and touch icons, OG images, the 3D phone. Widgets use the new symbols and colours (they don't show the mark itself). Decision 283.

### Colour — "Ink"
- Accent **#3441D5 light / #949FFF dark** (hue 235°, a touch of violet; not systemBlue or a Tailwind default). Fills under white text `#303ECF` / `#4551D3` (7.7 / 6.2 : 1); accent words `#303AC0` / `#9EA8FF` (7.6 / 8.3 : 1 on the backgrounds) — all past WCAG AA, enforced by the website build check.
- Warm paper `#F6F3EC` light, soft charcoal `#141418` dark; aura retuned (Ink, lilac, warm paper / Ink, violet, deep teal) and the seasonal layer nudged to match; green done and red danger kept. Categories re-ordered — Indigo first; the orange one is now "Amber" (still stored as `ember`). The mood ramp keeps its own indigo → sand → amber.
- One source (`shared/design-tokens.json`) regenerated iOS, widgets, web app, website, PDF, avatars and the 3D scene. Before/after: `00-before-after-light.png`, `00-before-after-dark.png`. Decision 282.

### Custom icons (`04-icon-set.png`)
- 25 custom **SF Symbol templates** with Ultralight / Regular / Black masters (interpolated by iOS for every weight and scale): the 4 tabs, +, dictate, ✦, photo, camera, scan, category, mood, search, lock, share, Recently Deleted, new page / add task (+ menu, widgets, Control Center), and Profile rows (sync, export, invite, devices, widgets, memories, appearance, calendar). The same drawings as SVG paths in the web app. Every control keeps its accessibility label. Decision 284.

## Part 6 — Ship
- **Tests:** iOS 248 unit (incl. crypto) pass; UI suite 0 failures (26 opt-in recording/share tests skipped as usual); API 75; web 53 unit + 23 build checks. The full run caught one regression from the rename — quick add's month names (`(?:ember)` in Sept/Nov/Dec) — fixed.
- **Release build: 0 warnings, 0 errors.** CI: see Known issues / HANDOFF for the final run.
- **/vibesec (auth + everything touched):** no findings. OAuth callbacks redirect only to two fixed targets with a closed set of reasons (no open redirect); the state prefix only chooses between them; logs carry Google's error code and an error class name, never tokens, emails or bodies; the `account_deleting` reason is only reachable after proving the Google identity; web photo retries are bounded and same-origin; `npm audit` 0 in api and web; gitleaks clean on every commit. Decision 285.
- **Website:** new colours, mark, favicon, app screenshots (`scripts/site-shots.sh`), OG images (`scripts/og/`, now committed) and a changelog entry; Pages deploys on push.
- **TestFlight 0.1.0 (107)** uploaded with `scripts/testflight.sh`.

**Files changed:** ~260 (`git diff --stat a5b7c6f`). Key: `api/src/{routes/auth.ts,auth/google.ts}`, `api/test/oauth.test.ts`, `api/wrangler.jsonc`, `ios/Folio/Features/{Account/SignInProblem.swift,Calendar/Panel/DayPanel*.swift,Calendar/Grid/{PhotoLoadKey,PhotoTile}.swift,EntryDetail/FullPhotoImage.swift}`, `ios/Folio/AppIcon.icon`, `ios/Folio/Resources/Assets.xcassets/{Colors,Symbols,AppMark.imageset,AppTint.colorset}`, `ios/FolioWidgets/{Assets.xcassets,WidgetPalette.swift}`, `shared/{design-tokens.json,brand/}`, `scripts/{brand,og}/`, `scripts/{brand-shots,site-shots}.sh`, `web/src/{app/ui/{Icons,Shell,common}.tsx,app/ui/calendar/DayPanel.tsx,icons/folio-icons.ts,components/{Mark.astro,brand-mark.ts}}`, `web/public/{favicon.svg,icons,og,img/app}`.

**Deviations from SPEC:** none; SPEC updated (§3.1, §3.2, §3.8, §3.10, §6.2, §10.2, §10.2a).

**Manual steps needed from the owner:**
1. Install 0.1.0 (107) from TestFlight and run "Only you can test" below.

**Only you can test**
1. Sign in on the new build with **Google** (new account needs an invite now — use your own account, which is exempt), then **Apple**, then **email**; and sign out / in again with an existing account.
2. A friend: make an invite in Profile → Invite a friend, have them sign up with it (a brand-new email should be asked for the code).
3. The new icon on your Home Screen in light, dark, tinted and clear.
4. Replace a photo on an entry and go back: the day panel card should show the new photo at once.

**Open questions for the Architect:** none.

**Known issues:**
1. Two website app screenshots (`widgets-*`, `web-entry-*`) still show the old orange: the widget shot needs widgets added by hand on a Simulator, the web one a signed-in web app. Both are small images on Features; refresh next batch.
2. Real Google/Apple/email sign-ins weren't run from here (needs account passwords or an inbox) — your test list item 1.

**Next phase ready:** yes.
