# Batch H report

Batch H = rebuild the marketing website in `/web` as a story-driven, 3D site (Parts 1–3) and restyle the web app's sign-in screens to match (Part 4). The web app at `/app` is otherwise unchanged. Shape per SPEC §18. Contact sheet: `docs/screenshots/batch-h/00-contact-sheet.png`.

---

WEBSITE (BATCH H) REPORT

**Built:**
- **Part 1 — story and copy:** `docs/WEBSITE_COPY.md` — one promise ("Your days, kept."), problem-first sections (scattered memories, to-dos apart from life, nagging streaks, who reads your thoughts, time zones, no time to type), "a day with Folio" (08:10 greeting · 15:20 task · 21:40 dictated entry), five use-case stories (traveller, student, new parent, paper diaries, two friends — labelled as made up), and a short note from the maker instead of reviews. No testimonials, ratings, counts or logos anywhere.
- **Part 2 — pages and navigation:** glass sticky nav (Features · How it works · Privacy · About · FAQ · **Sign in** · **Get started**, both to `/app`) with a full-screen glass menu on phones. Home: hero → problem → a day with Folio → features story → use cases → privacy → iPhone + web → FAQ preview → maker's note → closing call to action → footer (company details unchanged). New pages: Features (every feature with a real screenshot), How it works (3 steps), Privacy & security (plain-English encryption with an animated diagram: phone → lock → server sees only scrambled text → your other device), About, FAQ, Download (store buttons only when `site.ts` has a link). Support, Delete account, Changelog, Open source and 404 brought up to date (they still said sync and the web were "coming"). Per-page OG images.
- **Part 3 — 3D and motion:** a real-time 3D phone (our own rounded model, Folio's real calendar screenshot as its screen) floating over a shader aura; it leans toward the cursor and turns and rises as you scroll. Scroll stories: four "scattered" fragments gather into one calendar day; the day story pins the phone while the sky goes dawn → afternoon → night; the October month assembles with day tiles flying in from depth, photo tiles flipping in, and Sunday 25's page lifting off into its entry; a 3D lock closes as you scroll while the entry's words turn into the scrambled text our server stores. 3D tilt on feature and story cards. Stack: Motion (already in the SPEC) + React Three Fiber; no smooth-scroll hijacking (DECISIONS 215–217).
- **Part 4 — polish:** `/app` sign-in, unlock and key screens restyled (warm aura, serif headline, pill buttons, home link; no logic changes). Light and dark, 1440 px and 375 px, Reduced Motion and low-power fallbacks checked. Sitemap lists every page except `/app` and `/404`; robots unchanged.

**Performance and quality (Lighthouse 13.5.0 in Brave, local server with gzip and the real headers):**

| Page | Form | Performance | Accessibility | Best practices | SEO | LCP | TBT | CLS |
|---|---|---|---|---|---|---|---|---|
| Home | mobile, light | 99 | 100 | 100 | 100 | 2.0 s | 80 ms | 0 |
| Home | mobile, dark | 99 | 100 | 100 | 100 | 2.0 s | 20 ms | 0 |
| Home | desktop, light | 100 | 100 | 100 | 100 | 0.4 s | 0 ms | 0 |
| Home | desktop, dark | 100 | 100 | 100 | 100 | 0.4 s | 0 ms | 0 |
| Features / How it works / Privacy & security / About / FAQ / Download / Privacy policy / Support | mobile | 100 | 100 | 100 | 100 | 1.1–1.6 s | 0 ms | 0 |
| `/app` sign-in | mobile | 99 | 100 | 100 | 63* | 2.1 s | 0 ms | 0 |

\* `/app` is `noindex` on purpose (DECISIONS 200).

**Live check (2026-10-30, after Pages deployed 256ae2b):** https://folio.devilsense.com serves every new page (200), the new CSP and the 3D hero; Lighthouse mobile on the live home page **100 / 100 / 100 / 100** (LCP 1.6 s, TBT 50 ms, CLS 0).

- Home first-view JavaScript: **26.0 KB gzip** (budget 200 KB). The 3D chunk (236 KB + React DOM 63 KB gzip) loads only after the page has loaded and gone idle, only near the viewport, and on touch devices only after the first scroll or touch; never with Reduced Motion, Save-Data, little memory, few cores or a software renderer. Canvases stop rendering off screen.

**Files changed:** ~120 across 5 commits (c524c0c, 1457eff, 0906e07, 256ae2b + this report). Key: `docs/WEBSITE_COPY.md`; `web/src/components/home/*` (Hero, Problem, DayStory, CalendarStory, UseCases, PrivacyBand, Everywhere, Closing); `web/src/three/*` (Phone, Lock, shapes, mount); `web/src/scripts/{home,three-gate,aura,motion-common,page}.ts`; `web/src/pages/{features,how-it-works,security,about,faq,download}.astro`; `web/src/components/{Nav,Footer,PageHead,Shot,CipherDiagram}.astro`; `web/src/styles/global.css`; `web/src/app/app.css` + `ui/AppRoot.tsx` (gate); `web/public/img/app/*` (28 screenshots), `web/public/og/*`; `web/scripts/check-build.mjs`.

**Screenshots / recordings** (`docs/screenshots/batch-h/`):
- `01-home … 14-404` — every page, full length, `desktop`/`phone` × `light`/`dark` (56 JPEGs, static layout as seen with Reduced Motion).
- `15-motion-*` — home with motion and 3D on: hero, problem (gathered), day morning/afternoon/night, calendar (assembled, page lifted), privacy lock (closed, text scrambled); desktop + phone, light + dark.
- `16-app-signin-*` — the restyled web app sign-in, desktop + phone, light + dark.
- `rec-01-hero.mp4` (0.5 MB, 13 s) — cursor tilt, scroll turn. `rec-02-scroll-story.mp4` (1.3 MB, 32 s) — problem → day story → calendar assembly → lock.
- `00-contact-sheet.png` — the motion states.

**Tests:** web `npm test` — typecheck, unit tests, build and **22 build checks** pass (new: every page has its own existing OG image; nav has all sections; CTAs render only when configured on Home and Download). CI "API & web" and "Secret scan" green on the Part 2/3 pushes.

**Security:** gitleaks clean on every commit. `/vibesec` on `/web`: no findings (DECISIONS 222) — CSP unchanged (no new origins, no `eval`), no secrets or source maps in bundles, no cookies or storage on marketing pages, `npm audit` 0.

**Deviations from SPEC:** SPEC §11.2's nav updated to the owner's Batch H nav (Sign in / Get started instead of "Open web app"). The site no longer lists Open source and Support in the nav; both are in the footer.

**Manual steps needed from the owner:**
1. Open https://folio.devilsense.com in desktop Safari and scroll the home page once — this session couldn't capture desktop Safari (WebKit was checked on the iPhone and iPad Simulators).
2. If Beta App Review approved build 56, put `https://testflight.apple.com/join/88BuzSRc` in `web/src/config/site.ts` → `testflightUrl` (the Join button then appears on Home and Download), or tell the next session to.
3. Check the use-case stories and the maker's note read the way you want to speak about Folio (`docs/WEBSITE_COPY.md`).

**Open questions for the Architect:**
1. Should the store button sit in the nav once the App Store link exists (today: Sign in · Get started)?

**Known issues:**
1. The restyled unlock/recovery-key screens weren't screenshotted (they need a signed-in account with a key); they share the sign-in screen's `Gate` and CSS.
2. React Three Fiber 9.8.2 logs a console warning ("THREE.Clock … deprecated") when the 3D loads; harmless, not an error, and gone when R3F moves to `THREE.Timer`.
3. On phones the 3D phone appears after the first scroll (by design, for battery and Lighthouse); until then the poster shows.

**Next phase ready:** yes.
