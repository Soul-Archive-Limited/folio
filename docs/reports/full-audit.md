# Folio 1.0 — full hands-on audit

_11–12 November 2026, Batch O, before the 1.0 upload. Two passes: my own hands-on test, and an independent reviewer that never saw the code (only SPEC, the screenshots and the running app; its raw table is in `docs/screenshots/batch-o/review/FINDINGS.md`)._

## How it was tested

| Area | How | Result |
|---|---|---|
| Every iPhone screen | `scripts/audit-shots.sh` — 44 screens each on iPhone 17 Pro and iPhone SE (3rd gen), light, dark, default text and the largest size (AX5): 264 screenshots | Findings below |
| iPad | Same 44 screens on iPad Pro 13" landscape, light and dark | Clean (a few frames retaken after a slow launch under load) |
| Brand-new user | Onboarding steps 0–5 on both iPhones and both text sizes; keyboard on the first-line and name steps | Findings A1–A4, R1 |
| Existing user | Sample diary: calendar, day panel, composer (formatting, photos, place, mood, dictation and ✦ demo), entry, Journal (timeline, photos, Year in Pixels, Places, folding months), search, To-do (quick add, edit, groups), Profile (all 9 pages, search, Edit profile, avatars, categories), Recently Deleted, scan, On this day, celebrations, seasons, Face ID lock (simulated), Apple Calendar events (seeded) | Findings below |
| Full iOS suite | 330 tests (303 run, 27 opt-in skipped), 0 failures; unit tests rerun after the fixes: 289 pass | ✔ |
| Opt-in flows | Scan → entry, PDF preview, search, place search → "Tate Modern" → save (network on) | ✔ |
| Share extension | Photos → Share → Folio | Not re-run: iOS 26.5's Photos ignores synthetic taps in the share sheet (the test's grid lookup was fixed; Share isn't found). Code unchanged since Batch J, when it passed |
| Accounts on the local API | New account (18+ box, email code, recovery key), second iPhone signs in → QR link approved, page written on A arrives on B, Devices, delete account (re-auth with code, type DELETE) → guest; local D1 afterwards: users 0, sessions 0, records 0, blobs 0, key envelopes 0 | ✔ |
| Web app | Playwright e2e: every screen × phone/iPad/desktop × light/dark, console clean, axe 0 serious, all main flows (unlock, entries, Undo, Recently Deleted, quick add, search, places, mood, Year in Pixels, invites, PDF, keyboard, Profile, Edit profile, celebrations) | 244 pass (24 skipped by design) after one test expectation was updated for the new future-day line |
| Website | 10 pages × 390/1440 px × light/dark, console clean | Findings W1–W3 |
| Widgets, Control Center, Shortcuts, notifications | Not re-run this batch (unchanged since Batch J's tests); the Shortcuts tile colour was still orange — fixed (C5) | — |

## Findings

Severity: **Critical** = data loss, privacy/security breach, crash, likely App Review rejection; **High** = a main flow broken or misleading; **Medium** = partly broken or clearly confusing; **Low** = minor; **Cosmetic** = polish. "R" = the independent reviewer's id (F01…), "A" = mine. Screenshots: `docs/screenshots/batch-o/audit/` (a…) and `…/review/` (r…).

### Critical

| # | Screen | Steps | Cause | Status |
|---|---|---|---|---|
| A2b | Onboarding → sync step, iPhone SE | My first fix for A2 (below) made the title fit but pushed **"Not now — keep it on this iPhone"** (guest mode) below the fold — App Review must be able to skip sign-in | Layout chose the scroll variant | **Fixed** before anything shipped: a no-icon variant keeps the guest button on screen (a02-after) |

### High

| # | Screen | Steps | Cause | Status |
|---|---|---|---|---|
| R1 (F01) | Onboarding → Start with today | Fresh install → Get started → tap the line field | The keyboard still shrank the step despite `ignoresSafeArea(.keyboard)`; the step was then taller than its space and got centred, so the title slid under the Dynamic Island (a10-before) | **Fixed**: steps with a field are pinned to the top with `minHeight: 0`, so only the bottom goes behind the keyboard (a10-after); Return now adds the line |
| R2 (F02) | Guided tour | Tap Next on the tour cards | Taps on the card's padding reached the screen underneath (the glass had no hit shape), opening an entry mid-tour; a Next tap landing just after a look-only step moved on by itself skipped the next step | **Fixed**: the card takes all touches; a Next within 0.8 s of an automatic advance is ignored. The reviewer's slow synthetic taps made the auto-advance race far likelier than on a phone |
| R3 (F03) | Calendar at AX5, dark | Largest text, dark mode | The list's selected row used `accent` (light lilac in dark) under white text (~2:1) | **Fixed**: `accentStrong`, as everywhere else; the list also opens with the selected day centred instead of past the header |

### Medium

| # | Screen | Steps | Cause | Status |
|---|---|---|---|---|
| A1 / R5 | Calendar header | Pick any day not today → "Septe… 2026" (iPhone 17 Pro and SE) | The Today pill left too little room; scaling to 70 % wasn't enough | **Fixed**: falls back to the short month ("Sep 2026"); VoiceOver reads the full name (a01) |
| A2 / R4 | Onboarding → sync step | iPhone SE, default text | Title and subtitle truncated; icon touched the progress bar | **Fixed** (a02) |
| A3 | Onboarding steps 1–5 | iPhone SE | Subtitles truncated ("You can alwa…") | **Fixed**: headings never truncate |
| A4 | Onboarding, all steps | Largest text (both iPhones) | Every title cut, chips split letter by letter | **Fixed**: steps scroll at accessibility sizes; chips go to one column (a04) |
| A5 / R10 | Composer tool row | Largest text | Icons outgrew their 44 pt squares and overlapped | **Fixed**: icon row stops growing at xxxLarge, like system toolbars (a07) |
| A6 | Journal header and month headers | Largest text | "Jour-nal" beside the mode toggle; "OC-TO-BER" squeezed by the divider line | **Fixed**: toggle moves under the title; month label gets priority; the count never splits (a05) |
| A7 / R8 | Profile card | Largest text | "Ed / it / pro / file" beside the name | **Fixed**: button moves under the name (a06) |
| A8 | Edit profile | Largest text | "Ch oos e ph oto" | **Fixed**: buttons stack (a08) |
| R6 (F06) | Tour card | Any step | Clear glass: the screen's text showed through the card's words | **Fixed**: solid surface under the glass |
| R7 (F07) | Task composer | Type a title, Save | Reviewer saw "Book dentist book dentist" | **Not reproduced**: typed once it saves once. The reviewer typed twice because the Simulator showed text late |
| R9 (F09) | To-do | Largest text | Titles cut at 2 lines, notes at 1 | **Fixed**: wrap fully at accessibility sizes (notes up to 3 lines) |
| R11 (F11) | Continue with email | Empty field | "you@example.com" placeholder drawn as a blue link (a localized key auto-linked the address) | **Fixed**: verbatim placeholder in the placeholder colour |
| W1 | Website → Features | Desktop | Single-feature groups ("Bring it in", "Get things done") put the title on the right and the text under the image | **Fixed** (a11) |
| W2 | Website → Features → Lock | Any | The fresh Lock screenshot showed the Simulator's passcode prompt (no Face ID enrolled) | **Fixed**: previous Lock shots kept |
| W3 | App Store screenshots | `docs/appstore/` | iPhone set was from 29 Oct: orange, old day marks, no places, old Profile — would misrepresent the binary (guideline 2.3) | **Fixed**: retaken at the required sizes (Batch O Part 3) |

### Low

| # | Screen | Steps | Cause | Status |
|---|---|---|---|---|
| A9 | Calendar, iPhone SE | After Folio was force-quit with unsaved writing | "Continue your draft" floats over the empty day's "Add task" line (a09) | **Open** — rare (only after a force-quit with a draft); the pill can be tapped away by resuming or discarding. Fix later by giving the panel the pill's height |
| A10 | Onboarding chip "Memories" | iPhone SE | Hyphenated "Memo-ries" | **Fixed**: one line, shrinks slightly |
| R12 (F12) | "What will you keep here?" | Nothing selected | Selected chips changed fill only | **Fixed**: check mark on selected chips. "Skip" as the primary button when nothing is picked is intended |
| R13 (F13) | Day panel / Journal | A page with no title | Card showed bold "Untitled" over the words; the page itself shows no title | **Fixed**: the words lead (Journal uses the first line) |
| R14 (F14) | Quick add | "Lunch next friday noon" on Wed 11 Nov | Gives Fri 13 Nov | **Needs your decision** — British usage often means the 20th; the parser (and the web's copy of it) treats "next Friday" as the coming one |
| R15 (F15) | Sign-in buttons | 18+ box not ticked | Reviewer saw no hint | **No change**: since Batch L a tap on a dimmed button points at the box and says why; the Apple button greys more than the others because it's black |
| R16 (F16) | To-do | — | Search above the title; grey group bands | **No change**: deliberate (Batch I) |
| R17 (F17) | Profile → Your data (and Widgets, Privacy) | — | Page title repeated as the section header | **Open (Low)** — harmless; tidy later |
| R18 (F18) | Composer | Type `- [ ] buy film` | Markdown typed by hand isn't turned into a checklist | **No change**: checklists come from Aa → Checklist; typed Markdown stays text |
| R19 (F19) | Composer, future day | Write for next Thursday | "What happened today?" and "Kept on …" | **Fixed** on iPhone and web: "What's planned for this day?" and "Saved for …" |
| R20/R21 | Docs | SPEC §12 / APPSTORE | Google scopes said `openid email profile`; stale "final name/icon" items; age-rating wording | **Fixed** |
| R27 (F27) | DEBUG `-FolioOpen recentlyDeleted` | Without `-FolioTab profile` | Ignored | **No change**: documented to need `-FolioTab profile` (not user-facing) |

### Cosmetic

| # | Screen | Cause | Status |
|---|---|---|---|
| A11 / R22 | Onboarding → Your look | Theme previews used the retired orange | **Fixed**: Ink |
| A12 | Shortcuts | Folio's Shortcuts tile was orange | **Fixed**: navy |
| A13 | Composer category chips | The row scrolls to the chosen chip, leaving a cut chip at the left edge | Open — normal for a scrolling chip row |
| A14 | Recently Deleted, iPhone SE | "Recently Dele…" beside Empty and Select | Open — standard iOS truncation |
| A15 | Website home | "New: the web app matches the iPhone" was stale | **Fixed**: "New in 1.0: places on your pages" |
| R23 (F23) | Calendar header | Header moves ~5 pt when the Today pill appears | Open — tiny; the pill's glass height differs from the round buttons |
| R24 (F24) | Onboarding check mark | System blue | **Fixed**: Ink |
| R25 (F25) | Mood colours | Good/Bright read coral rather than amber | Open — they come from the shared tokens used on all platforms; a palette change is your call |
| R26 (F26) | Save toast | Rows showed through the clear glass | **Fixed**: solid surface under the glass |
| A16 | Scan sample | The sample page's sketch is read as garbled text | Sample-image artefact; correctable in the review sheet |

**Totals:** Critical 1 (found in my own fix, fixed before shipping) · High 3 (all fixed) · Medium 16 (14 fixed, 1 not reproduced, W-items fixed) · Low 13 (6 fixed, 1 needs your decision, 2 open, 4 no change by design) · Cosmetic 10 (6 fixed, 4 open).

## Needs your decision

1. **"next Friday"** (R14): coming Friday (today's behaviour) or the Friday of next week?
2. **Mood colours** (R25): keep coral/orange-red for Good/Bright, or move them towards amber (all platforms)?

## Design review — Ink theme, icons, spacing, type, motion, consistency

**What works.** The Ink accent is used with restraint: one deep blue for selection, the + button and links, white on `accentStrong` for every filled state (after R3, without exception). Warm paper in light mode and a soft charcoal in dark mode read as a diary, not a dashboard. The custom symbols (Nib book, tab icons, tool row) are consistent in weight with SF Symbols. Spacing follows one scale (4/8/12/16/24/32) and the glass groups line up on 16 pt margins on iPhone, readable widths on iPad. Motion is short and interruptible, and Reduce Motion swaps every movement for a fade. iPhone, iPad, the web app and the website share colours, marks, icons and copy — the e2e screenshots and the website's app shots match the iPhone screen for screen.

**What still looks basic or off — honestly:**
1. **Largest text sizes were an afterthought.** Before this audit, AX5 broke onboarding, the composer tools, Journal and Profile. They're fixed now, but other places will still wrap awkwardly at AX5 (Profile stat labels "Days writt…", the Look step's theme names). A full VoiceOver + AX5 pass on a real iPhone is still the honest next step (APPSTORE "before public release" 5).
2. **Glass over content.** Clear glass reads beautifully over a calm background and poorly over text. The tour card and toasts now have a solid layer; the floating draft pill (A9) and the To-do quick-add bar still let rows show through.
3. **Small screens.** The SE is usable everywhere, but the Profile root needs a scroll there and onboarding's sync step drops its icon to fit. Fine, not elegant.
4. **The calendar header** still nudges when the Today pill appears (R23), and long month names now abbreviate — tidy, but a fixed-width header would be calmer.
5. **Mood colours** sit closer to coral than to the warm amber the spec describes (R25), and coral is the one leftover that still recalls the old orange brand.
6. **Web app vs iPhone.** Parity is good, but the web has no map (by your decision) and its Places list is plainer than the iPhone's map view.
7. **Website.** Strong home page; the Features page is long and phone-shot heavy. A shorter page with 6–8 hero features would read better.

## Costs and limits

All prices read on the providers' own pages on 11 Nov 2026.

| Provider | Free plan | Paid |
|---|---|---|
| Cloudflare Workers | 100,000 requests/day; 10 ms CPU per request | $5/month account minimum: 10 M requests/month (+$0.30/M), 30 M CPU-ms (+$0.02/M) |
| D1 | 5 M rows read/day, 100 k rows written/day, 5 GB total, **500 MB per database** | 25 B reads/month, 50 M writes/month (+$1/M), 5 GB (+$0.75/GB-month), **10 GB per database** |
| R2 | 10 GB-month, 1 M Class A, 10 M Class B ops/month, free egress | $0.015/GB-month; Class A $4.50/M; Class B $0.36/M |
| Durable Objects (SQLite) | 100 k requests/day, 13,000 GB-s/day | 1 M requests/month (+$0.15/M), 400 k GB-s (+$12.50/M); WebSocket messages billed 20:1; hibernating objects aren't billed for duration (Folio's UserHub hibernates) |
| Pages | Unlimited static requests, 500 builds/month | — |
| Turnstile | Free, unlimited challenges | — |
| Resend | 100 emails/day, 3,000/month | Pro $20/month for 50,000 |
| Apple | Developer Program $99/year; TestFlight: 100 internal + 10,000 external testers, builds last 90 days; free apps pay no commission; 25 Xcode Cloud hours/month | — |

**What one active user costs Folio** (measured from the code: one encrypted row per page/task/category, photos stored as three renditions — ≤2048 px HEIC ~400–600 KB, 1080 px ~150 KB, 240 px ~20 KB):
- Worker requests: ~10 a day (two app opens with a live socket, two pushes, pulls, a photo upload) — SPEC §15.2's target.
- D1: ~1–1.5 MB of encrypted rows per year of daily writing; a few hundred rows read per sync.
- R2: ~0.57 MB per photo; at one photo a day ≈ 0.2 GB per user per year. Each photo is 3 Class A writes; each other device downloads 2 renditions (Class B).
- Email: only at sign-in, re-authentication and deletion — a few a month per user.

**Monthly cost after a year of daily use with one photo a day** (Apple's $99/year not included):

| Active users | R2 photos | D1 | Requests/day | Plan | Approx. cost/month |
|---|---|---|---|---|---|
| 2 | 0.4 GB | 3 MB | ~20 | Free | **$0** |
| 10 | 2 GB | 15 MB | ~100 | Free | **$0** |
| 100 | 21 GB | 150 MB | ~1,000 | Free (R2 over 10 GB) | **~$0.20** (R2 storage only) |
| 1,000 | 210 GB | 1.5 GB | ~10,000 | **Workers Paid** (D1 database over 500 MB) | **~$8** ($5 + ~$3 R2) |
| 10,000 | 2.1 TB | 15 GB | ~100,000 | Workers Paid + D1 split | **~$45** ($5 + ~$31 R2 + ~$7 D1 + DO/requests ~$1; Resend Pro +$20 if sign-ins pass 100/day) |

**Which limit comes first:** R2's free 10 GB of photo storage (at about 50 user-years of daily photos — roughly 50 people after a year), then D1's **500 MB per database on the free plan** (about 350 user-years), then Resend's 100 emails a day if many people sign in on the same day. Workers requests (100 k/day) only matter around 10,000 daily users.

**What to change first when Folio grows:**
1. ~100 users: nothing — R2 overage is cents. Watch R2 storage in the dashboard.
2. ~300–1,000 users: move to **Workers Paid ($5)** before the D1 database reaches 500 MB (writes would start failing at the limit).
3. ~5,000 users: move encrypted record bodies over a size threshold from D1 into R2 (D1's 10 GB per database is a hard ceiling), or shard D1 by user; and **Resend Pro** if sign-in emails pass 100 a day.
4. Any time: consider R2 Infrequent Access only for old photo originals — cheaper storage but retrieval fees, so not for thumbnails.
