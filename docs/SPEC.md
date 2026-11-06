# FOLIO — Master Build Spec (v2)

> Working name: **Folio** (rename everywhere with one search-and-replace once the final name is chosen).
> Publisher: **Soul Archive Ltd** (company no. 16186654, England & Wales).
> This file is the single source of truth. Every phase prompt refers to sections here by number. Never contradict it without asking.
> v2 changes: own free Cloudflare backend, sign in with Apple / Google / email code, end-to-end encryption, optional account (guest mode), delete account, guided tour, motion-polish phase.

---

## 0. Rules for the builder (read before writing any code)

1. **iOS app: native Swift 6 + SwiftUI.** No React Native, Expo, Flutter or web views inside the app.
2. **Minimum iOS 26.0**, built with the latest Xcode / iOS SDK installed. Gate anything newer than iOS 26 with `if #available`.
3. **Backend: Cloudflare only** — one Worker (TypeScript) + D1 + R2 + one Durable Object class, plus Cloudflare Pages for the website. Designed to run on the **free plan** until a few thousand daily users (§15.2). No other servers.
4. **Local-first.** Every write goes to the on-device SwiftData store first; the app is fully usable offline and **without an account** (guest mode). Sync is a layer on top, never a gate.
5. **End-to-end encryption.** All diary content (entries, photos, tasks, categories, settings) is encrypted on the device before upload. The server only ever sees ciphertext plus the minimal metadata in §10.3. Soul Archive Ltd cannot read anyone's diary.
6. **No analytics, no ads, no tracking, no third-party SDKs in the iOS app.** Apple frameworks only. Google sign-in is done with `ASWebAuthenticationSession` (no Google SDK).
7. **Secrets never live in the app, the website or git.** See §13. No `.env` files are ever committed or shipped. A secret scanner blocks commits.
8. **Always check current API docs with Context7 before using an API** that is iOS 26+, Cloudflare Workers/D1/R2/Durable Objects, Better Auth, or Sign in with Apple/Google OAuth. These changed in 2025–2026; never code them from memory. Log every API decision in `docs/DECISIONS.md`.
9. Project generated with **XcodeGen** (`project.yml` committed; `.xcodeproj` git-ignored). Backend uses **Wrangler**.
10. After every phase: build, run (iOS Simulator latest iPhone Pro, light AND dark; backend via `wrangler dev` + tests), screenshot every screen touched, and finish with the **Phase Report** (§18).
11. Small files: one view per file, views under 200 lines, logic in `@Observable` models / actors. `#Preview` with realistic sample data for every screen. Unit tests for all crypto, sync and auth logic.
12. Accessibility and motion quality are not optional (§3.9, §3.6). Every animation is interruptible and runs at 120 fps on ProMotion.

---

## 1. Product in one paragraph

Folio is a private diary built around a calendar. You open the app and see your month; days you wrote on show a tiny photo or a coloured dot, days with tasks show a ring. Tap a day and its entries and tasks appear underneath. Writing opens in the bottom half of the screen so the calendar stays visible. You can write for any past date, so old paper diaries can be moved in. A to-do list feeds the same calendar: completed tasks stay on their day, shown as done. Use it instantly with no account, or sign in with Apple, Google or email to sync across iPhone and the web — encrypted so only you can read it. No streaks. No nagging.

### Identifiers
| Item | Value |
|---|---|
| Display name | Folio |
| Bundle ID | `com.devilsense.folio` |
| URL scheme (OAuth callback) | `folio://auth` (+ Universal Link `https://folio.devilsense.com/auth/callback`) |
| Website + web app | `https://folio.devilsense.com` (Cloudflare Pages) |
| API | `https://folio.devilsense.com/api/*` (Worker route on the same domain — same origin for the web app, no CORS needed) |
| Sign in with Apple Services ID (web) | `com.devilsense.folio.web` |
| Support / privacy email | `support@devilsense.com` / `privacy@devilsense.com` |
| Transactional email sender | `no-reply@folio.devilsense.com` |
| GitHub | `github.com/Soul-Archive-Limited/folio` (public, open source) |

---

## 2. Navigation map

```
Launch (static) → Greeting intro (~1.4 s, skippable)
  First launch only: Welcome → Start with today → What you'll keep → You (name + picture) → Your look → Sync choice (Apple / Google / Email / Not now)
                       → [if signed in, new account] Recovery key → Tour
                       → [if signed in, existing account on new device] Unlock → Tour
                       → [Not now] Tour
→ Main TabView: Calendar (opening tab) · Journal · To-do · Profile
Floating glass "+" (Calendar, Journal, To-do): tap = New entry · long-press = New entry / New task / Dictate
```
- Native iOS 26 `TabView` with `Tab(...)` items (real Liquid Glass). Icons: `calendar`, `book.pages`, `checklist`, `person.crop.circle`.
- `.tabBarMinimizeBehavior(.onScrollDown)` on Journal and To-do.
- "+" = floating 56 pt Liquid Glass circle, bottom-trailing above the tab bar, in a `GlassEffectContainer` with a `glassEffectID` so it **morphs into the composer sheet**.

---

## 3. Design system

### 3.1 Direction — "Quiet Glass"
Rules distilled from the 7 reference pins:
1. **One hero per screen.** Calendar on Calendar; the photo on an entry; the big numeral in the greeting.
2. **Monochrome + one accent** ("Ink" — a deep fountain-pen blue with a hint of violet; Batch K replaced "Ember"). Colour comes from your content — photos and category colours.
3. **Content as colour.** Day cells with a photo show it as a tiny rounded thumbnail. The app's signature.
4. **Big confident numerals.** Dates are typography.
5. **The sheet keeps context.** Lists and composers live in bottom sheets over the calendar.
6. **Glass sits on light.** Glass floats over a soft, slowly drifting colour "aura" at 10–18% opacity — never a rainbow.
7. **A greeting with a summary** with inline SF Symbols.
8. **Floating pill controls** with depth — for primary actions and chips only. Headers stay compact: a smaller in-content title that becomes a slim glass pill in the top bar on scroll; no extra full-width containers (Batch I).

### 3.2 Colour tokens (asset catalog light/dark + Swift `Color` tokens; never raw hex in views)
| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#141418` (soft charcoal) | `#F6F3EC` (warm paper) | Background |
| `bgElevated` | `#1E1E24` | `#FFFDF9` | Cards when Reduce Transparency is on |
| `ink` | `#F3F2F0` | `#17161C` | Primary text |
| `inkSecondary` | ink @ 62% | ink @ 60% | Secondary text |
| `inkTertiary` | ink @ 36% | ink @ 34% | Placeholders, out-of-month days |
| `hairline` | `#FFFFFF` @ 8% | `#000000` @ 7% | Separators |
| `accent` ("Ink") | `#949FFF` | `#3441D5` | Marks, rings, icons, glyphs (non-text) |
| `accentStrong` | `#4551D3` | `#303ECF` | Fills under white text: today, selection, primary buttons (white on it ≥ 6:1) |
| `accentText` | `#9EA8FF` | `#303AC0` | Accent-coloured words and links (≥ 7:1 on `bg` and `bgElevated`) |
| `done` | `#7ED69B` | `#2FA35A` | Completed marks |
| `danger` | `#FF5A5F` | `#D93A3F` | Destructive actions |
| `aura1/2/3` | `#3441D5` / `#7A4FD0` / `#1E6A86` | `#B8C0FF` / `#E4CDF4` / `#F2DCC0` | Aura blobs (Ink, lilac, warm paper; dark: Ink, violet, deep teal) |

**Category palette** (12, tuned light/dark), in picker order (Batch K): Indigo, Ocean, Teal, Sage, Violet, Plum, Rose, Coral, Amber, Sand, Olive, Graphite — a new category takes the first unused one, so orange is no longer the default. Amber is stored as `"ember"` (keys in synced data never change). Labels on category colours auto-switch dark/light to pass WCAG AA.
Appearance follows system; Profile can force Light/Dark. Theme, Writing font and First day of week apply at once everywhere (the theme is set on every window, sheets included) and also appear on Folio's page in the iPhone Settings app (Settings.bundle), kept in sync both ways: a value changed in Settings wins over the last value Folio wrote there; anything else follows the synced setting (Batch I).

### 3.3 Typography
SF Pro for UI (`.monospacedDigit()` where numbers animate). Writing font: **New York** (default) or SF Pro. All styles use Dynamic Type (`relativeTo:`).
| Style | Size/weight | Use |
|---|---|---|
| `display` | 56 bold, tracking −1.5 | Greeting numeral, jump-sheet year |
| `title1` | 34 bold | Month title |
| `title2` | 22 semibold | Section headers, entry titles |
| `headline` | 17 semibold | Row titles |
| `body` | 17 regular | Entry text |
| `callout` | 15 regular | Previews |
| `caption` | 12 medium, uppercase, +0.6 | Weekdays, chips |
| `micro` | 10 semibold | Numbers on photo tiles |

### 3.4 Spacing, radius, glass
Spacing 4/8/12/16/20/24/32/40; side margin 20. Radii: day cell 12, card 22, chips/buttons capsule. Use `ConcentricRectangle` for nested shapes in glass. Glass via the system only: `.glassEffect(.regular, in:)`, `.regular.interactive()` for tappables, `.buttonStyle(.glass)` / `.glassProminent` tinted `accentStrong`; neighbours inside `GlassEffectContainer`. Material + border only as the Reduce Transparency fallback.

### 3.5 Aura background
`AuraBackground`: 3 blurred circles (radius 260–340, blur 90) drifting on 18–30 s paths via `TimelineView(.animation(minimumInterval: 1/30))`; 14% dark / 22% light; subtle seasonal hue shift per month; static under Reduce Motion; paused in background; ≤ ~2% CPU.

**Seasonal layer (Batch I).** A very subtle layer over the aura and behind every view: spring blossom drift, summer warm glow (with a few rising motes), monsoon rain streaks, autumn leaves, winter snowflakes — about a dozen small shapes at low opacity, only in the top third of the screen (fading out before the content), 20 fps at most. Off under Reduce Motion, in Low Power Mode, while the app isn't active and on frozen backgrounds; ≤ 2% CPU (measured +0.1–0.7% in the Simulator). Profile → Appearance → **Season effect**: Auto / Spring / Summer / Monsoon / Autumn / Winter / Off (device-only, default Auto). Auto uses today's month and the region set on the iPhone (no location permission):

| Climate | Regions | Seasons |
|---|---|---|
| Temperate north (default) | everywhere not listed below | spring Mar–May · summer Jun–Aug · autumn Sep–Nov · winter Dec–Feb |
| Temperate south (flipped) | AU, NZ, AR, CL, UY, PY, ZA, LS, SZ, NA, BW, BR, FK | spring Sep–Nov · summer Dec–Feb · autumn Mar–May · winter Jun–Aug |
| Indian subcontinent | IN, PK, BD, NP, BT | summer Mar–May · monsoon Jun–Sep · post-monsoon Oct–Nov (shown as autumn) · winter Dec–Feb |
| Tropical, wet summer | TH, MM, KH, LA, VN, PH, NG, GH, CI, SN, ML, BF, MX, GT, BZ, HN, SV, NI, CR, PA, CU, JM, HT, DO, PR, TT, BS | monsoon (wet) May–Oct · summer (dry) Nov–Apr |
| Tropical, wet winter | SG, MY, ID, BN, LK, MV, TL | monsoon (wet) Nov–Mar · summer (drier) Apr–Oct |

### 3.6 Motion language (quality bar: fluid, interruptible, never janky)
- All animations are **springs**: default `.smooth(duration: 0.35)`, interactive `.snappy`, confirmations `.bouncy(duration: 0.4, extraBounce: 0.1)`.
- **Interruptible:** any animation can be grabbed mid-flight (sheets, collapses, page swipes); gestures drive progress directly (no "play then wait").
- **Continuity:** elements that persist between screens use shared geometry (`matchedTransitionSource` + `.navigationTransition(.zoom)`, `glassEffectID` morphs). Nothing pops in without a transition.
- **No layout jumps:** reserve space for async content (thumbnails fade in inside fixed frames); keyboard and sheet heights animate together.
- Month title: `.contentTransition(.numericText())` + slight blur-in. Day tap: selection springs 0.6 → 1; panel rows stagger 30 ms with 20 pt rise.
- "+" → composer: Liquid Glass morph. Entry row → detail: zoom transition with the photo as shared element.
- Task tick: fill + checkmark trim 0→1 (0.25 s) + animated strike-through + `.success` haptic; after **1.2 s** the row moves to Completed.
- Onboarding pages: parallax on page swipe, content tied to scroll offset.
- Reduce Motion: cross-fades only, ≤ 0.2 s.
- Target: 120 fps on ProMotion; verified with Instruments (Animation Hitches) in Phase 13.

### 3.7 Haptics (`.sensoryFeedback`)
Selection on day tap and month change; `.success` on task complete, entry save, sign-in; `.impact(.light)` on untick/chip toggle; `.warning` before destructive confirmation. One haptic per gesture maximum.

### 3.8 Iconography & imagery
**Folio's own icon set (Batch K)** for its signature concepts — tabs (calendar, journal = the mark's nib book, to-do, profile), +, dictate, ✦ writing tools, photo, camera, scan, category, mood, search, lock, share, Recently Deleted, new page / add task (widgets, controls, the + menu) and the main Profile rows (sync, export, invite, devices, widgets, memories, appearance): custom SF Symbol templates (`Assets.xcassets/Symbols`, also in the widget extension) with Ultralight / Regular / Black masters that interpolate to every weight and scale, generated by `scripts/brand/symbols.swift`, which also writes the same drawings as 24-px paths for the web (`web/src/icons/folio-icons.ts`). SF Symbols for everything generic (close, chevrons, checkmarks, formatting). Every control keeps its accessibility label. Photos: radius 22 with 1 px inner hairline. Empty states: one large SF Symbol on glass + one sentence.
**Photo views follow the photo, not the entry (Batch K):** every photo view (calendar cell, day panel and Journal cards, entry detail, composer, web) remembers which photo id its image belongs to; when the same card is given a different photo (a replaced photo) it drops the old image and loads the new one at once. Caches are keyed by photo id (+ rendition and size); a photo's bytes never change under the same id. The widget snapshot names thumbnails by photo id. On the web a photo whose bytes haven't arrived yet (synced from another device a moment ago) is retried three times.

### 3.9 Accessibility
≥ 44 pt hit areas · day cells read e.g. "Tuesday 14 October, 2 entries, 1 task done" + rotor "Days with entries" · Reduce Transparency → `bgElevated` cards · Increase Contrast → stronger hairlines/secondary text · Dynamic Type to AX5 (calendar switches to week rows at AX sizes) · colour never the only signal.

### 3.10 App icon
**Mark (Batch K): "Nib book"** — an open diary whose gutter is a fountain-pen nib (slit and breather hole), paper on an Ink tile (gradient `#4150E0` → `#252FA6`). Under 32 px a simpler drawing (no slit, wider gutter). One source: `scripts/brand/generate.py` (shared/brand SVGs, launch/greeting/lock/privacy-cover `AppMark`, PDF cover, website logo, favicon, PWA and touch icons, 3D phone) — the three directions considered are in `docs/screenshots/batch-k/01-logo-directions.png`. **App icon:** an Icon Composer document, `ios/Folio/AppIcon.icon` (one glass layer, Ink fill; dark = charcoal fill with an Ink-tinted mark; tinted and clear come from the system), checked with `ictool` renders.

---

## 4. Launch, greeting & privacy cover

### 4.1 Launch screen
Static: `bg` + centred app mark (72 pt), via Info.plist `UILaunchScreen`.

### 4.2 Greeting intro (every cold launch; skipped if resumed within 10 min; tap to skip)
0.0 s mark at centre (identical to launch screen) → 0.15 s mark scales 0.85 and rises 60 pt, aura fades in → 0.3 s greeting types in by word (blur→sharp, 40 ms/word) in `title1` → 0.6 s summary line in `callout` with inline SF Symbols built from real data (omit zero parts; if all zero, a "quiet" line) → 1.4 s dissolves upward into Calendar; mark morphs toward the "+" button.

**Greeting pool** — random, never the same as last launch, `{name}` dropped (with its comma) if no name:
- *Early 04–07:* "Up with the sun, {name}." · "Early start, {name}." · "The world's still quiet, {name}." · "First light, {name}." · "Fresh page, {name}."
- *Morning 07–12:* "Good morning, {name}." · "Morning, {name}. Coffee first?" · "A new day, {name}." · "Hello, {name}. Today's unwritten." · "Rise and write, {name}." · "Morning light, {name}."
- *Afternoon 12–17:* "Good afternoon, {name}." · "Hey {name}, how's the day going?" · "Halfway there, {name}." · "Afternoon, {name}." · "Taking a pause, {name}?"
- *Evening 17–21:* "Good evening, {name}." · "Evening, {name}. How was today?" · "Welcome back, {name}." · "Winding down, {name}?" · "The day's almost written, {name}."
- *Night 21–04:* "Still up, {name}?" · "Late thoughts, {name}?" · "Good night, {name}." · "Quiet hours, {name}." · "The best ideas come late, {name}."
- *Special (1-in-3 when applicable):* 1st of month → "Hello, {Month}." · New Year's Day → "Happy New Year, {name}." · entry exactly 1+ years ago → "On this day in {year}, you wrote something."
- *Quiet summaries:* "Nothing due. Just you and the page." · "A clear day ahead." · "No tasks. Plenty of room."
Strings in `Greetings.swift`, localisable.

### 4.3 App-switcher privacy cover
On `.inactive`/`.background`, instantly overlay `bg` + static aura + app mark + short line, so diary content never appears in the app switcher. The line is picked fresh each time the app leaves the foreground from a pool of eight ("See you soon, {name}.", "Your pages are safe, {name}.", "Back whenever you're ready, {name}.", "Your days are kept, {name}.", "Locked away safely, {name}.", "Until next time, {name}.", "The page will wait for you, {name}.", "Only you can read this, {name}."; each also without the name) and never repeats the last one (Batch I). Fade out 0.2 s on `.active`. On by default; toggle in Profile → Privacy.

### 4.4 Lock Folio (Batch J)
Profile → Privacy & Security → **Lock Folio** (Face ID / Touch ID / Optic ID, falling back to the passcode — `LAContext` `.deviceOwnerAuthentication`) and **Lock: Immediately · After 1 minute · After 5 minutes · After 15 minutes**. Device-only, never synced; turning it on or off asks for Face ID / passcode first; without a device passcode it can't be turned on ("Set a passcode in the Settings app to lock Folio.").
- The lock is its **own window above everything in every scene** (level above alerts), so sheets, menus, deep links, widget taps and shortcuts all open underneath it. The moment Folio goes to the background with the lock on, that window goes up as the §4.3 cover (centred mark + cover line) — the app-switcher snapshot is the cover even if "Hide content in app switcher" is off (that toggle is greyed while the lock is on). Coming back within "Lock after" fades it away (0.2 s); otherwise it locks.
- **Locked:** mark and a time-of-day greeting ("Still up, Sam?") in the upper third (clear of the system's Face ID panel in the middle), Face ID asked for at once, and a glass **Unlock with Face ID** button near the bottom. Cancel keeps it locked; a real failure says "Couldn't unlock. Try again." The keyboard is put away when it locks.
- **Cold launch with the lock on:** the launch screen (bg + mark) until the lock window is up, so nothing renders visibly first; the lock screen replaces the greeting intro.
- A clock that went backwards locks (never trust a negative gap). If the device passcode was removed since, the lock opens (iOS no longer protects anything).
- Returning from the Face ID sheet is not a new visit (no re-lock loop).

---

## 5. Data model (SwiftData, local-first)

All synced models share: `id: UUID` (unique), `createdAt`, `updatedAt` (client clock), and sync metadata:
```swift
var serverVersion: Int64?   // last version acknowledged by server (nil = never synced)
var isDirty: Bool           // local change not yet pushed
var isDeleted: Bool         // tombstone, kept until server acknowledges, then purged
```

**`dayKey`:** the owner travels across time zones constantly. A diary day must never move when the phone changes time zone. Store the user-chosen calendar day as a floating string `"YYYY-MM-DD"` plus optional `minutesFromMidnight`. All grouping uses `dayKey`, never `Date` comparisons.

```swift
@Model final class Category { id; name: String (1–24, unique ci); colorKey: String; symbol: String?; sortIndex: Int; trashedAt: Date?; unassignedIDs: [UUID]?; + shared fields }
@Model final class Entry { id; title: String (0–120); bodyMarkdown: String; dayKey: String; minutesFromMidnight: Int?; categoryID: UUID?; trashedAt: Date?; @Relationship(deleteRule: .cascade) photos: [EntryPhoto]; + shared }
@Model final class EntryPhoto { id; entryID: UUID; sortIndex: Int; @Attribute(.externalStorage) imageData: Data; @Attribute(.externalStorage) thumbData: Data; pixelWidth: Int; pixelHeight: Int; blobUploaded: Bool; + shared }
@Model final class TaskItem { id; title: String (1–200); notes: String? (≤ 2000); dayKey: String?; minutesFromMidnight: Int?; categoryID: UUID?; isCompleted: Bool; completedAt: Date?; sortIndex: Int; trashedAt: Date?; + shared }
```
- Photos: max 10/entry; GPS EXIF stripped; HEIC long edge ≤ 2048 at quality 0.75 (target ≤ 600 KB); 240 px JPEG thumb.
- Deleting a category un-assigns its items and remembers which ones (`unassignedIDs`), so restoring it re-links them.
- **Deleting (moving to Recently Deleted, §5.2) is the only way an item leaves the calendar. Completing a task never removes it.** `trashedAt` (in Recently Deleted) and `isDeleted`/`isTombstone` (permanently deleted, kept only until the server acknowledges it) are separate.
- Synced user settings (display name, appearance, writing font, first weekday, default category, profile picture — `avatar` "folio:01"…"folio:24" / "photo" with a 256 px JPEG `avatarPhoto`) live in one encrypted `Settings` record; device-only settings in `@AppStorage`.
- Schema v5 (Batch J): `Entry.mood: Int?` (1 Heavy · 2 Low · 3 Steady · 4 Good · 5 Bright), in the encrypted payload; a synced value off the scale is dropped. v4's Entry and EntryPhoto frozen in `FolioSchemaV4Models.swift`. Lightweight migration.
- Schema v4 (Batch I): `TaskItem.remindAt` (floating local "YYYY-MM-DDTHH:mm"), `repeatRule` (JSON), `parentID` (subtasks); `UserSettings.avatar`, `avatarPhoto`. Lightweight migration.
- `PreviewData.swift`: ~40 entries across 3 years (some with sample photos), 25 tasks, 6 categories; DEBUG "Load sample data".

### 5.1 Formatted text
Only: bold, italic, underline, strikethrough, highlight, one heading level, bulleted list, numbered list, checklist, quote. Edit with the iOS 26 rich-text `TextEditor(text: $attributedString, selection:)` + an `AttributedTextFormattingDefinition` limited to these. Canonical storage = Markdown via `MarkdownCodec` (underline `<u>…</u>`, highlight `==…==`, checklist `- [ ]`/`- [x]`). Round-trip unit tests; the same test vectors (JSON fixtures in `/shared/markdown-fixtures.json`) are used by the web editor.

### 5.2 Recently Deleted
- **Delete moves an entry (with its photos), task or category to Recently Deleted** by setting `trashedAt`. No "Are you sure?": a toast "Moved to Recently Deleted · Undo" (§6.14 toast rules). Only *Delete now* and *Empty* ask first (with a `.warning` haptic).
- **Trashed items are invisible everywhere else:** Calendar markers, day panel, Journal (Timeline and Photos), To-do, Jump-sheet dots, Profile stats, the greeting summary, "Same day in other years", category counts, ✦ and export (export has an "Include Recently Deleted" toggle, off by default).
- **Screen "Recently Deleted"** (Profile → Your data → Recently Deleted · N; also a quiet "Recently Deleted · N" link at the end of the Journal timeline and the To-do list when N > 0): segmented Entries / Tasks / Categories; rows show the original date and "N days left"; tap → read-only preview with Restore / Delete now; swipe leading Restore, trailing Delete now; Select → Restore selected / Delete selected; "Empty" with confirmation. Glass style. Empty state: "Nothing here. Deleted items stay for 30 days."
- **Restore** clears `trashedAt`, putting the item back on its original day and category (a completed task stays completed). Toast "Restored to Tue 27 Oct · Show" (Show jumps to that day). Restoring a category re-links the entries and tasks it un-assigned, unless they've been given another category since; a name clash gets a number ("Travel 2").
- **Auto-purge after 30 days:** items whose `trashedAt` is more than 30 days ago are permanently deleted (tombstoned for sync; photos and any draft of that entry removed) on launch, on foreground and in background refresh, only while protected data is available. The clock used is a stored high-water mark (`max(now, last seen now)`), so moving the device clock backwards never brings anything back or extends a countdown in a confusing way; nothing permanently deleted is ever resurrected.
- "Erase data on this iPhone" also empties Recently Deleted.

---

## 6. Screens — iOS

**[G]** = Liquid Glass surface.

### 6.1 Onboarding + sign-in (first launch)
Redesigned in Batch I after a study of Day One, Structured, Flighty, Stoic, Opal, Apple Journal and Apple's first-run screens (`docs/ONBOARDING.md`). A `NavigationStack` of steps — going back is the system's interactive back swipe, which can't rest between two steps — with a thin segmented progress bar in the top bar and one sentence per screen. Steps never resize for the keyboard; focus drops before every push and when a step disappears, so no keyboard is carried between steps. Reduce Motion: fades instead of the fly-in and tile assembly.
1. **"Your days, kept."** — a month assembling tile by tile; "A private diary built around your calendar. Encrypted, so only you can read it."; **Get started**.
2. **"Start with today"** — write one line or pick today's photo (PhotosPicker, no permission) and watch it fly into today's square on a mini calendar; it saves a real entry for today. **Not now** skips.
3. **"What will you keep here?"** — Memories · Travel · Tasks · Old diaries · Gratitude · Work (any); each except Tasks creates a matching category.
4. **You** — "What should we call you?" (optional; Return continues) and a picture: the monogram or a Folio avatar.
5. **Look** — Light · Dark · Match iPhone, applied live; Season effect on/off.
6. **Sync choice** — headline "Keep your diary in sync?" sub "Use Folio on the web and on a new iPhone. Encrypted end to end."
   - **Continue with Apple** (system `SignInWithAppleButton`, `.black`/`.white` style per appearance, placed first per Apple HIG)
   - **Continue with Google** (white button with the official Google "G" mark per Google's branding guidelines)
   - **Continue with email** → email field → 6-digit code screen (auto-fill from Mail via `.textContentType(.oneTimeCode)`, resend after 30 s, errors inline)
   - **Not now — keep it on this iPhone** (text button). Guest mode: everything works offline; Profile offers sign-in later.
   - **Above the buttons (Batch L):** an unticked box "I'm 18 or older and agree to the Terms and Privacy Policy" (links). Apple, Google and email stay disabled until it's ticked; the choice is sent with the sign-in (`adult`) and never stored on the device. Re-authentication (delete account) doesn't show it.
   - Footer (Batch L): "We use your email only to sign you in — never for marketing. Your diary is encrypted so only you can read it."
7. **Recovery key** (new account only) — §10.4. Must be saved before continuing.
8. **Unlock** (existing account, new device) — automatic if the key is in iCloud Keychain; otherwise "Scan from your other device" (shows QR) or "Enter recovery key".
9. → Greeting intro → **Tour** (§6.15).
No permission prompts during onboarding.

### 6.2 Calendar tab (opening screen)
Over `AuraBackground`:
- **Header:** month `title1` + year `title2` `inkSecondary`; tapping opens Jump sheet (chevron glyph). Right [G] group: Filter (category menu) and **Today** pill (morphs in only when off today/current month). Small sync indicator dot (only shown while syncing or on error).
- **Weekday row** `caption` `inkTertiary`, locale first weekday (Profile override).
- **Month grid [G panel, r22]:** infinite horizontal paging (`.scrollTargetBehavior(.paging)`, `scrollPosition(id:)`, lazily extended ±240 months, extend near edges). 6×7, gap 6.
  - Cell states (one zone per meaning, so marks never overlap — Batch I): default · out-of-month (`inkTertiary`, tap jumps month) · today (accent bold number + 1.5 pt accent outline; on a photo tile, an accentStrong pill behind the number) · selected (accentStrong rounded square, white number, spring; on a photo, a 3 pt accent frame) · **entry with photo → latest photo thumbnail fills the cell**, `micro` white number top-left, "+2" badge bottom-right if more · entry without photo → up to 3 category dots under the number · tasks → one small mark in the top-right corner, inside the cell: a hollow ring while any is open, a green check once all are done · filter active → non-matching markers at 15%.
  - "What do the marks mean?" key: Profile → Help, and a long-press on the weekday row (VoiceOver action too).
  - Long-press day → New entry / New task for this day.
  - **Search (Batch J):** pull the day panel down past its top ("Pull to search" → "Release to search", a selection haptic) or tap the magnifier beside Filter → the search sheet (§6.17).
- **Day panel:** "Saturday, 25 October" `title2` (no button beside it — Batch K). Entries section (cards: 64 pt photo, title, 2-line preview, category chip, time) → detail via zoom. Tasks section (checkbox toggles in place; completed shown checked, struck, 50% — they stay). Empty: one calm line, "Nothing written yet. **Add task**" (a text button, accent colour, 44 pt tall). New pages for the day come only from the floating "+" (tap = page for the selected day; long-press = page / task / dictate), so there is one way to do each thing. Web: the same line; on phone widths the floating + has the same long-press (or right-click) menu, on desktop the sidebar's New entry writes for the selected day.
  - Scrolling the panel up collapses the grid to the selected week (swipeable week strip); scroll to top or tap title to expand. Fully interactive (tracks finger). It always comes to rest fully open or fully collapsed: the release uses the system's projected (velocity-aware) target, and any scroll that stops in between (an interrupted deceleration, content changing height) settles to the nearer end. Only the grid's height, offset and fades read the drag progress (Batch I).
  - **On this day (Batch J):** at the top of the day panel, a glass card listing pages from this date in earlier years (year in bold, title, mood), newest first, three at most ("and N more"); tap opens the page. Nothing when there are none.
  - **Apple Calendar (Batch J, opt-in):** a "Calendar" section in the day panel (colour bar, "All day" / 09:30 / "until 10:00", title; read-only) and a short bar in the bottom-left corner of a day cell that has events (its own zone). Off until Profile → Apple Calendar is turned on.
  - The day panel runs down to the tab bar: only the round "+" floats over it, and the panel's last row can scroll fully clear of the button.
  - After a full close with unsaved writing, a "Continue your draft" pill floats beside the "+": tap to reopen the draft's composer with it restored; swipe it away to discard the draft (Batch I).

### 6.3 Jump sheet
`.medium` glass sheet: horizontal snapping year strip (1900 → current+10, selected in `display`), 4×3 month capsules (dot if month has entries), [G] "Go to today". Jump = quick fade+scale.

### 6.4 Composer (half sheet)
- `.presentationDetents([.medium, .large])`, `.presentationBackgroundInteraction(.enabled(upThrough: .medium))` — the calendar stays visible and tappable; tapping another day moves the entry to it (haptic tick, date pill animates). Drag indicator visible; `.interactiveDismissDisabled(hasUnsavedText)`.
- Top bar: Cancel · date pill [G] (compact DatePicker popover + optional time) · **Save** (`.glassProminent` accentStrong; disabled until there's content).
- Title (`title2`, "Title"); rich body (writing font; "What happened today?" / past date: "What do you remember about this day?").
- Keyboard toolbar [G]: Aa (format popover) · Photo (`PhotosPicker`, up to 10, no permission) · Camera (asks at use) · Category · **Mood** (Batch J: popover "How did it feel?" with five glyphs; tap again or Clear to unset) · Mic (§8) · ✦ (§9, only if available).
- **Mood glyph (Batch J):** Folio's own — a ring filling from the bottom (⅕ … full), on a diverging ramp: Heavy indigo · Low indigo 50% · Steady sand · Good amber 55% · Bright amber. Never faces or emoji. Shown small on entry cards (day panel, Journal) and with its word in entry detail.
- Photo strip (reorder by long-press, × remove). Category chips with inline "+".
- Draft autosave every 2 s locally; "Continue your draft?" on reopen. Cancel with changes → "Discard this entry?" / Keep writing for a new entry, "Discard changes?" / Keep editing for an existing one; the sheet closes only after the dialog has gone (Batch I).
- The sheet reads as its own layer: the screen behind dims slightly (more toward the sheet), a stronger material with a fine highlight along the top edge, in light and dark.
- Checklists: tapping a box ticks or unticks it directly; Return continues the list; Return on an empty item ends it. Same in the web editor.

### 6.5 Entry detail
Zoom-in from the card. Photo carousel (4:3, paging, pinch to full-screen) · date line `caption` · category chip · title · rendered body (line height 1.45). Toolbar: Edit (composer `.large`) · Share · ••• Change date / Duplicate / Delete (to Recently Deleted, §5.2). Share offers: **Share as text** (a plain `String` with a subject and preview, which every app accepts — Messages, WhatsApp, Notes, Mail), **Share text and photos**, and **Share as image** — one card, or for entries too long for a card a choice of "Single card" / "All pages (N)": numbered 1/N story-sized images (1080 × 1920) with the text flowing across them so nothing is cut (Batch I). Footer strip **"On this day"** with the subtitle "You wrote on 29 October in 2025" when applicable.

### 6.6 Journal tab
Compact title "Journal" with the *Timeline* / *Photos* toggle beside it; category chips [G]; "Past day" in the top bar. Timeline: month headers in a lighter style than the cards (small-caps month, count, hairline, chevron — no card), cards with cover photo (16:9, title over gradient) or text cards. **Year in Pixels (Batch J)** is the third Journal mode: a big year number, Mood | Category toggle, then 12 month columns × 31 day rows of rounded squares — the day's latest mood (or first category); written without one = ink 22 %; nothing written = ink 7 %; future = 3 %; today outlined in ember; impossible dates empty. Years swipe sideways (first written year → this year). Tap a day: one page opens in place, several go to that day on the calendar. Legend underneath. No streaks, no "days in a row". Months fold: this month and last month open by default, older months closed; tap to open or close; the choice is remembered (Batch I). Photos: 3-column masonry of all photos. "Write for a past day" button opens composer with date picker. Empty: "Your journal is empty. Tap + to write your first page." Pull down for the search field (§6.17); while it's open, results replace the timeline and open in the Journal's own stack.

### 6.7 To-do tab
Compact title, category chips, and a date button in the top bar that shows one date's tasks only. **Active** in collapsible groups (state persisted): Overdue (accent) · Today · Tomorrow · This week (the next five days) · Later · No date; within a group by date, then time, then drag order. Tasks can be dragged to reorder among tasks of the same date (a drop onto another date springs back). Tapping a task opens it for editing; long-press keeps the menu. Scrolling or tapping outside the quick-add bar puts the keyboard away (Batch I). **Completed** (collapsible "Completed · 12", state persisted) by `completedAt` desc. Pull down for "Search tasks" (§6.17, tasks and subtasks only); results cover the list and open the task sheet. Row: 26 pt circular checkbox in category colour · title · 1-line notes · date/time chip.
**Complete flow:** tap → fill + check + strike + haptic → stays **1.2 s** → moves to Completed; undo toast [G] 4 s; tapping again during 1.2 s cancels. Untick in Completed → back instantly.
Swipes: leading Complete/Uncomplete; trailing Delete (to Recently Deleted, §5.2) · Edit · Date (Today / Tomorrow / Next week / Pick / Remove). Quick-add bar [G] above tab bar ("Add a task…") that understands natural dates and times at the start or end of the line — today, tonight, tomorrow, day after tomorrow, in/after N days|weeks|months, next week/month, (this) weekend, [on|this|next] Monday, on 5 Nov / 5th of November / November 5 / 5/11 (day first; month first in the US), times like 6pm, 6:30 pm, 18:30, at 7, noon, morning/afternoon/evening — with a live chip ("Tomorrow · 18:00") above the bar before saving (Batch I). "Today's papers" stays as typed. A bare "at 7" is the next 7 o'clock that hasn't passed; a time alone is today, or tomorrow once passed. Empty Active → "All clear." with `checkmark.seal`.

### 6.8 Task composer (`.medium` sheet)
Title (required) · Notes · Date toggle → graphical DatePicker · Time toggle (if date) · **Remind me** (Batch I) · **Repeat** · **Subtasks** · Category chips · Save. Existing task: Delete at bottom (to Recently Deleted, §5.2).
- **Remind me:** a date and time (default the task's time, else 09:00), "At the task's time" shortcut. Local notifications only — nothing goes through the server. The first time it's turned on, a glass explainer comes before the system prompt; denied → "Open Settings". Stored as a floating local time (`remindAt`) that syncs; every device schedules its own (≤ 60 nearest, iOS allows 64), in its own time zone. Notification actions: **Done** (ticks; a repeating task adds its next), **Snooze 1 hour**, **Tomorrow** (same time) — snoozes sync too.
- **Repeat:** Never · Every day · Every weekday · Every week · Every month (same day, or the month's last day) · Every year · Custom (every N days/weeks/months). Ticking a repeating task keeps it done on its day and adds the next one (with its subtasks, time and a reminder moved by the same days), once — a re-tick doesn't duplicate it. Same rule on the web.
- **Subtasks:** tick in place, add with Return, swipe to remove. They show under their parent ("1/3" on the row), not as tasks of their own, and go to Recently Deleted and come back with it. Rows also show a bell (reminder) and repeat arrows. The web app keeps all three and repeats on tick; editing them is on the iPhone for now.

### 6.9 Profile tab
Inset-grouped glass sections:
- **Header card [G]:** profile picture, name (tap to edit), "Writing since March 2019 · 412 pages". No streaks anywhere. Tap the picture → **Choose photo** (PhotosPicker, then a circular crop: drag to move, pinch to zoom; saved as a 256 px JPEG) or **Folio avatars** (24 original "page spirits" — a little page with a folded corner, a face and a coloured dot, each with its own palette and personality; vector art generated with the web's copies by `scripts/avatars/generate.py`) · Remove picture. Without one, the monogram. The picture syncs encrypted with the settings and shows in Profile, the greeting, Devices ("This device") and the web app (sidebar, Profile — where a Folio avatar can also be chosen —, Devices) (Batch I).
- **Your archive** 2×2 tiles: Entries · Photos · Days written on · Tasks done (tap → filtered tab).
- **Account:**
  - Guest: "Sync & web access" card with the three sign-in buttons (same as onboarding step 5).
  - Signed in: email / provider icon · Sync status (Up to date · Syncing… · Offline — will sync later · Error, tap for detail) · last synced · "Sync now" · **Devices** (model + OS such as "iPhone 15 Pro · iOS 27.1" or "Chrome on macOS", date added, last seen, "This device"; rename any device — the name is encrypted with the Data Key; "Sign out" each, "Sign out other devices"; DECISIONS 189) · **Recovery key** (Face ID/passcode gated "Show recovery key") · **Link a browser or device** (shows QR, §10.4) · **Sign out** (asks: keep diary on this iPhone or remove it) · **Delete account** (§10.6, `danger`).
- **Categories** → manager (§6.10).
- **Appearance:** Theme, Writing font, First day of week.
- **Writing:** Default category · Show photo tiles on calendar.
- **Dictation & Intelligence** (§8–9) with availability explanation.
- **Privacy & Security:** **Lock Folio** + "Lock" delay (§4.4) · Hide content in app switcher.
- **Widgets:** Show details on Home Screen · Show details on Lock Screen (§6.18).
- **Memories:** On this day notification + Time (§6.19). **Apple Calendar:** Show Apple Calendar events (§6.2).
- **Your data:** **Recently Deleted · N** (§5.2) · Export as JSON + photos zip (decrypted, local; "Include Recently Deleted" toggle, off by default) · **Export PDF** (§6.21) · Erase data on this iPhone (also empties Recently Deleted).
- **Help:** "Show the tour again" · "What do the marks mean?" · Support & FAQ · Contact support (mailto).
- **About:** Website · Privacy Policy · Terms · Open Source (GitHub) · Acknowledgements · Rate Folio (`requestReview` only here) · Version · "Made by Soul Archive Ltd".

### 6.10 Categories manager
Rows: colour dot, symbol, name, count. Drag reorder, swipe delete (to Recently Deleted, §5.2; Undo or Restore re-links its items), tap edit. Edit sheet: name, 12-swatch grid, optional symbol from 40 curated SF Symbols, live chip preview. Max 30.

### 6.11 Dictation overlay
Glass capsule above keyboard: live waveform from mic level, volatile words `inkTertiary`, final words `ink`, Pause · Done; text inserted at the cursor.

### 6.12 Intelligence menu (✦)
Glass popover: Suggest a title · Polish grammar (keeps my words) · Find tasks in this entry. Preview → Accept/Discard; nothing applied without acceptance.

### 6.13 Recovery key screen
Large monospaced key on two balanced lines of 13, each grouped 4-5-4, on a [G] card (e.g. `K7QM-4XT2A-…`, 128-bit, Crockford base32; DECISIONS 191). Copy · Save to Files (a `.txt` "Folio Recovery Key") · Print. Clear warning: "This key is the only way to read your diary on a new device if your iPhone is lost. We can't recover it for you." Confirm by typing the last 4 characters. Continue enabled only after confirming.

### 6.14 States & feedback
Glass toasts for saved / deleted (Undo, 4 s) / sync issues. Human error copy ("Couldn't sync right now. Your diary is safe on this iPhone — we'll try again."). Never show raw codes (log with `Logger`, no content in logs). Skeleton shimmer only for photo thumbnails.

### 6.15 Guided tour (TipKit)
Shown once after onboarding; replay from Profile → Help. Uses Apple **TipKit** popover tips, one at a time, each waiting for the user's action (not timed), with "Skip tour":
1. Month grid — "Your month. Days you write on get a photo or a dot."
2. A day (today) — "Tap a day to see its pages and tasks." (advances when tapped)
3. "+" — "Write your first page. The calendar stays above while you type." (opens composer; tip in composer points at the photo/category/mic toolbar)
4. To-do tab — "Tasks you finish stay on their day, ticked."
5. Profile tab — "Make categories with your own colours." (guest only: also "Turn on sync any time.")
Tips use the glass style, respect Reduce Motion, never reappear once done.

### 6.16 iPad
Resizable `NavigationSplitView` (sidebar tabs · calendar · day panel/detail). No extra design work in v1.
**Batch L:** the month column is wider by default (ideal 560 pt, 360–760) so cells grow in portrait; Journal, To-do, Profile and Year in Pixels keep a centred readable column on wide windows (`readableWidth()`: 760 pt, the photo wall 1100 pt) and the To-do quick-add bar lines up with it; nested horizontal pagers zero the inherited margins and are keyed by their width. **Keyboard** (menu bar and ⌘ overlay, focused window only): ⌘N New Entry (selected day) · ⇧⌘N New Task · ⌘1–4 tabs · ⌘T Today · ⌘[ / ⌘] month · ⌘F Search · ⌘↩ Save in both composers. **Pointer:** every `.pressable` control has the system highlight hover effect. Compact windows (narrow Split View or Stage Manager sizes) use the iPhone layout through the horizontal size class. Screenshots: `docs/screenshots/batch-l/ipad/` (13" and 11", portrait and landscape, light and dark); App Store: `docs/appstore/ipad-0*.jpg`.

### 6.17 Search (Batch J)
One field per place: Calendar (pull-down / magnifier → sheet), Journal and To-do (pull-down search drawer). Searches entry titles and text, category names, task titles, notes and subtasks — **on the device only**, from an in-memory index built off the main thread (`SearchIndexer`, rebuilt in the background after writes while a search is open; changed pages only). Nothing new is written to disk; nothing leaves the device.
- **Words:** case-folded; accents dropped from Latin letters only (Hindi vowel signs and other scripts' marks are part of the word); Chinese and Japanese characters count one per word. Each typed word must prefix-match a word of the item (AND). Shared rules with the web, pinned by `shared/search-fixtures.json`.
- **Filters** (glass chips): Category (several) · Photos (pages with photos) · Dates (Any time, This month, Past 3 months, This year, Last year, Choose dates…) · Open or done (tasks only when set). Filters alone are a query.
- **Results:** "Pages · N" then "Tasks · N", newest first; the matched word starts are highlighted (accent wash + bold, never colour alone); page snippets start just before the first match; matching subtasks show under their task. Over 300 → "N more — add a word or a filter". Tap opens the page in place (pushed in the same stack; Back returns to the results) or the task sheet.
- Empty: "Search titles, pages, categories and tasks. Everything stays on this iPhone." · No match: "No matches for “…”." · First build: "Getting your diary ready…".
- 10,000 entries: a query is a binary search per word per item (a few ms); tested in `SearchIndexTests`.

### 6.21 PDF export and print (Batch J)
Profile → Your data → **Export PDF**: From / Until (GMT day pickers) with Quick ranges (This year · Last year · Last 3 years · Everything), toggles **Photos** and **Tasks**, then **Create PDF** → a progress bar (Stop cancels) → a PDFKit preview with **Share** (share sheet) and **Print** (`UIPrintInteractionController`).
- The book: A5 pages on paper colour, always the light palette. **Cover:** profile picture (photo, Folio avatar, or the initial in an Ink circle), "Sam's diary" / "My diary", the range in italic, "41 pages", the Folio word. **Each month opens a new page** with a big serif month name, the year in Ink italic, "N PAGES" and a hairline. **Entries** in date order: an ember small-caps date line (weekday, day, month · time · mood word), the title in New York bold, the body with every §5.1 style (bold, italic, underline, strikethrough, highlight, heading, bullets, numbers, checklists ☐/☑, quotes), photos at text width (≤ 250 pt tall, ≤ 1000 px JPEG), the day's tasks under "TASKS" (☑ struck when done) if chosen, and a small "·  ·  ·" between days. Footer: month and page number.
- Made entirely on the device in a background task (its own `ModelContext`, TextKit 1 laying each month over as many pages as it needs), with progress per day and a background-task grace period if Folio is sent away mid-way. The file goes to the app's temporary folder with complete file protection and nowhere else until shared. Three years of the sample diary: 38 pages in ~3 s on the Simulator.

### 6.20 Bring things in (Batch J)
- **Scan a paper page** ("+" long-press → Scan a paper page): VisionKit's document camera (several pages; explainer before the camera prompt) or "Choose photos of pages" → text read on the device (`RecognizeTextRequest`, accurate, language correction; the device language, English and Hindi where iOS supports them — iOS 26.5 has no Hindi model; lines under 0.4 confidence are dropped) → a review sheet: the pages, **the date found on the page suggested** (numeric dates day-first except in the US, written dates via `NSDataDetector`, Devanagari digits, 1900 → tomorrow), the text in an editor → Save makes a new entry for that day with the text as paragraphs and the scans as photos (≤ 10; GPS stripped, resized like any photo) and a "Saved to Tue 12 Mar 2019 · Show" toast.
- **Share into Folio** (share extension "Folio" for up to 10 photos, text and a web link): a mini composer — the shared things, optional title and line, Day, "Add to that day's page" (when it has one), Category — then Save. The item is sealed with AES-GCM under an inbox key held in the Keychain (access group = the App Group, this device only, never synced) and written to the App Group inbox; Folio imports it on its next foreground as an ordinary local edit (new entry, or paragraphs + photos added to that day's latest page), deletes the file and says "Added 1 shared to Folio". The extension never opens the diary; its category list comes from a small sealed context the app writes.

### 6.19 Memories notification (Batch J)
Profile → **Memories** → "On this day notification" (off by default; glass explainer before the system prompt the first time; denied → Open Settings) + Time (default 08:00). Local notifications on this device for the next 7 days that have pages from earlier years: title "On this day", body "In 2025, you wrote something. Take a look back?" — the year only, never a title or words (Lock Screen). Rescheduled after changes and on foreground; tap opens today with the On this day card. Reminders keep up to 56 of iOS's 64 pending notifications.

### 6.18 Widgets, controls and shortcuts (Batch J)
All read a small **snapshot** the app writes to the App Group `group.com.devilsense.folio` (`Widgets/widget-snapshot.json` + the month's existing 240 px thumbnails), protected `completeUntilFirstUserAuthentication` (readable after the first unlock since a restart). It holds today's and tomorrow's tasks and open overdue ones (≤ 40), this and next month's grid (entry count, photo file, dot colours, task counts), one greeting per period and "on this day" years. Written ≤ 1 s after a change, on background and in background refresh, only when its content changed (then `reloadAllTimelines`). It's local and device-only: it never syncs and never reaches the server.
- **Home Screen:** **Today** (small: weekday + big date, greeting, "3 to do · 1 pages"; medium: + next 4 tasks; large: + 7 tasks and "On this day in 2025…") with an **interactive tick** per task; **Month** (small: mini grid with dots; large: photo tiles, dots, task marks, each day opens that day); **Quick add** (small: New page · Add task · Dictate). Timeline entries at each greeting change and midnight.
- **Lock Screen:** **Next task** (rectangular/inline) and **Today's count** (circular gauge, done of all today). Counts only unless "Show details on Lock Screen" is on.
- **Details:** Profile → **Widgets** → "Show details on Home Screen" (on) · "Show details on Lock Screen" (off). Details = task titles and photo tiles; with both off, titles and photos aren't even written to the snapshot. Titles and tiles are `.privacySensitive()`, so a locked device redacts them.
- **Ticks:** a widget can't open the diary, so `ToggleWidgetTaskIntent` queues the tick in the App Group (`pending-ticks.json`, last tick per task wins) and updates the snapshot at once; the app applies the queue on launch, foreground and background refresh as ordinary local edits (repeats spawn, it syncs).
- **Control Center / Action Button:** New Entry · Dictate · Add Task (open Folio there).
- **Siri & Shortcuts:** Add Task (title + optional date and time; runs in Folio's process without opening it; needs the iPhone unlocked; "Added “Buy stamps” for Fri 6 Nov.") · New Entry · Dictate Entry · Show Today · Open On This Day — phrases in `FolioShortcuts`.
- **Links:** `folio://new-entry|new-task|dictate|today|on-this-day|search|day/YYYY-MM-DD|task/<uuid>` — navigation only, nothing is written from a link; Lock Folio (§4.4) covers wherever it lands.

---

## 7. Permissions — only at the moment of use
| Permission | When | Purpose string |
|---|---|---|
| Photos | Never (PhotosPicker) | — |
| Camera | Tap Camera | "Folio uses the camera only when you choose to take a photo for an entry." |
| Microphone | First tap of Mic | "Folio uses the microphone only while you dictate. Audio is processed on your iPhone and never stored or sent anywhere." |
| Speech recognition | Only if the Speech API requires it (verify) | "Folio turns your voice into text on your iPhone. Nothing is sent to a server." |
| Face ID | Showing recovery key; approving a link; turning Lock Folio on/off and unlocking it (§4.4) | "Folio uses Face ID to protect your recovery key and diary." |
| Notifications | The first time a task's "Remind me" is turned on (Batch I), or the On this day notification (Batch J) | system |
| Calendars (full access, read) | Profile → Apple Calendar → Show events (Batch J) | "Folio shows your calendar's events beside your diary, on this iPhone only. They're never copied into Folio or sent anywhere." |
| Camera (scan) | Scan pages (Batch J) | same camera string, which now mentions scanning |
Before each system prompt: a one-line glass explainer with Continue / Not now. Denied → gentle "Open Settings" row.

---

## 8. Dictation — on-device, free
Speech framework **`SpeechAnalyzer` + `DictationTranscriber`** (verify with Context7). `AVAudioEngine` tap → convert to `SpeechAnalyzer.bestAvailableAudioFormat` → `AsyncStream<AnalyzerInput>`. Locale from Profile (default: the device language in the device's region, e.g. en-IN, en-GB, en-US — Batch I; check `supportedLocales`; download model via `AssetInventory` with progress row). Transcriber options: punctuation, volatile results, frequent finalisation. Contextual hints via `AnalysisContext.contextualStrings[.general]`: the person's name, category names and the entry's title. The capsule shows the elapsed time. After Done, when Apple's on-device model is available and at least three words were dictated, a small offer "Tidy punctuation and capitals?" — the result is applied only if every word is unchanged. Unsupported locale → hide Mic, mention the keyboard mic. Volatile results dimmed, finals committed. On-device only; audio never written to disk. Auto-stop after 2 min silence / 30 min total. One session at a time; ignore repeat taps within 600 ms.

## 9. Intelligence — Apple's on-device model, free
**Foundation Models** (`SystemLanguageModel.default`, `LanguageModelSession`, `@Generable`) — verify with Context7. ✦ shown only when `availability == .available`. **On-device model only — never Private Cloud Compute or cloud providers.** Features: Suggest a title (3 options), Polish grammar (diff preview), Find tasks (tick to add). Instructions: never add facts or change meaning; reply in the entry's language. One request at a time, cancel previous, ≥ 1.5 s apart, input ≤ ~6,000 chars, friendly handling of context/guardrail/availability errors.

---

## 10. Accounts, encryption & sync

### 10.1 Backend shape (`/api` folder, TypeScript, Wrangler)
- **Worker** `folio-api` on route `folio.devilsense.com/api/*`. Router: **Hono**. Validation: **zod** on every input.
- **D1** `folio-db`: users, accounts (provider links), sessions, verification codes, devices, `records` (ciphertext), `blobs` (photo metadata), `key_envelopes`, `link_requests`, `rate_limits` (fallback), `deletions_log` (user id hash + timestamp only).
- **R2** bucket `folio-blobs`: encrypted photos at `u/<userId>/<blobId>`.
- **Durable Object** `UserHub` (SQLite-backed, WebSocket **Hibernation API**) — one per user, only for real-time "something changed" pings.
- **Auth:** **Better Auth** on Workers + D1 (Apple, Google, email OTP plugins) — verify Workers/D1 compatibility with Context7 first. If it doesn't fit cleanly, use **Arctic** (OAuth) + own session tables. Record the choice in DECISIONS.md.
- **Email:** OTP emails via **Resend** free tier (HTTP API) initially; abstraction `EmailSender` so it can switch to Cloudflare Email Service when the account moves to Workers Paid.
- **Bot protection (web):** Cloudflare **Turnstile** (free) on the web email-code request.

### 10.2 Sign-in flows
- **Apple (iOS):** `ASAuthorizationAppleIDProvider` with a SHA-256 nonce → send identity token + raw nonce + authorization code to `POST /api/auth/apple/native` → Worker verifies JWT against Apple JWKS (aud = bundle ID), exchanges the code for a refresh token (stored encrypted at rest with a Worker secret — needed for revocation on deletion), creates/links user, returns session.
- **Apple (web):** OAuth redirect with Services ID `com.devilsense.folio.web`, return URL `https://folio.devilsense.com/api/auth/callback/apple`.
- **Google (iOS):** `ASWebAuthenticationSession` → `GET /api/auth/google/start?platform=ios` (PKCE, state) → Google → Worker callback → redirect to `folio://auth?code=<one-time code>` → app exchanges the one-time code (60 s, single use) for a session. Scopes: `openid email profile` only. No Google SDK.
- **Google (web):** standard OAuth redirect.
- **When an OAuth round trip fails (Batch K)** it always ends back in the app (`folio://auth?error=…`) or the web app (`/app?error=…`) with a reason, never an error page inside the sign-in sheet: `cancelled`, `expired` (state older than 10 min, a refused or used code, or the 60-s hand-off ran out — try again), `google_unavailable` (Google refused our client credentials — use Apple or email), `account_deleting`, `invite_required` / `invite_invalid`, else `failed`. The state carries its platform as a prefix (`i.` / `w.`) so even an unknown state returns to the right side. Each reason has its own message; the Worker logs Google's error code (never its description).
- **Email:** `POST /api/auth/email/start {email}` → 6-digit code, hashed (SHA-256 + server pepper), 10-min expiry, max 5 attempts, then invalidated → `POST /api/auth/email/verify`. Identical response whether or not the email exists (no account enumeration).
- **Linking:** same verified email across providers links to one user (Apple private-relay emails won't match — that's fine). Profile shows linked providers.
- **Sessions:** 256-bit random opaque token; only its SHA-256 stored in D1; 30-day sliding expiry; per-device row (name, platform, last seen). iOS: Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, not synchronizable. Web: `__Host-folio_session` cookie, `HttpOnly; Secure; SameSite=Lax; Path=/`. CSRF: SameSite + Origin check on all state-changing requests.

### 10.2b Accounts are 18+ (Batch L)
- **A new account needs `adult: true`** (JSON on `apple/native` and `email/verify`, `adult=1` on the OAuth start, carried in `oauth_states.adult`). Without it the server answers `403 age_required` **before anything single-use is spent** (same place as the invite check) and creates nothing; with it, `users.age_confirmed_at` records the time (migration 0004). Existing accounts and re-authentication never need it. OAuth failures return `error=age_required` to the app or web app, which explain it. Guest mode on iPhone is open to everyone and sends nothing.
- The Declared Age Range API (Texas SB 2420, in force since 4 June 2026) is planned before a public App Store release — `docs/COMPLIANCE.md` §5.

### 10.2a Invite-only sign-up (Batch J)
- **New accounts need a one-time invite** (8 Crockford base32 characters shown as `ABCD-EFGH`; typing is forgiving: case, spaces, O/0, I/L/1). Valid **7 days, single use**. Stored only as an HMAC (`OTP_PEPPER`) plus its last two characters; table `invites` (migration 0003), which account deletion clears.
- **Unaffected:** every existing account (any provider, or a verified email that links to one), the owner's own addresses and App Review's address (while `REVIEW_ENABLED`). Guest mode needs nothing. `INVITES_REQUIRED` (var in `wrangler.jsonc`) switches it: **"true" in production since Batch K (owner, 2026-11-06): Folio is private for the owner and one friend.** `OWNER_EMAILS` holds the owner's Apple address (Worker secret, never in a file). Setting it to "false" and redeploying reopens sign-up; with it off no one is asked for a code.
- **When it's asked for:** only when a sign-in would create an account. The server answers `403 invite_required` / `invite_invalid` **before anything single-use is spent** — the email code stays valid (it still counts attempts), Apple's authorization code isn't exchanged — so the app asks for the code and tries again: email → an "Invite code" field under the 6-digit code; Apple → a small sheet, then Sign in with Apple runs again with the invite; Google and web Apple → the code rides through the OAuth round trip as a hash in `oauth_states`, and the callback returns `error=invite_required` to the sign-in screen, which then shows the field. Invite tries: 10 per IP per hour.
- **Owner:** emails in the Worker secret `OWNER_EMAILS` (comma-separated). `/api/account/me` returns `canInvite`; Profile → **Invite a friend** (iPhone and web): "Make an invite" shows the code once, large, with Share ("Join me on Folio, a private diary. Your invite code: … Get Folio: …/download"); the list shows `····-··XY`, status (Until 12 Nov / Used / Revoked / Expired) and Revoke for open ones. At most 20 open invites; 30 made per day. API: `GET/POST /api/invites`, `DELETE /api/invites/:id`.

### 10.3 End-to-end encryption
- On first sign-in a random 256-bit **Data Key (DK)** is generated on the device.
- **Every record** (Entry, EntryPhoto metadata, TaskItem, Category, Settings) is serialised to JSON and encrypted with **AES-256-GCM** (iOS CryptoKit `AES.GCM`, web WebCrypto), random 96-bit nonce per write, associated data = `recordId|recordType|userId`.
- **Photos & thumbnails** encrypted the same way before upload to R2.
- **Server sees only:** record id, record type, server version, client `updatedAt`, deleted flag, ciphertext size, and the user's account email. No titles, text, dates (`dayKey` is inside the ciphertext), categories or photos.
- **DK storage:**
  - iOS: Keychain item with `kSecAttrSynchronizable = true` (iCloud Keychain) so the user's other Apple devices can unlock automatically; plus an in-memory copy while unlocked.
  - Server: only **wrapped** copies — DK encrypted with a key derived (HKDF-SHA256) from the **recovery key**, and per-device envelopes created during device linking. The server can never unwrap them.
  - Web: DK held in memory only; optional "Trust this browser for 30 days" stores it as a non-extractable `CryptoKey` in IndexedDB, wrapped by a device key.
- Crypto code lives in `FolioCrypto` (iOS) and `/web/src/crypto` (web) with **shared test vectors** (`/shared/crypto-vectors.json`) so both implementations agree byte-for-byte.
- No custom cryptography: only AES-GCM, HKDF-SHA256, X25519, SHA-256 from CryptoKit/WebCrypto.

### 10.4 Recovery key & linking new devices
- **Recovery key:** 128-bit random, shown as 26 Crockford-base32 chars in groups (§6.13). Never sent to the server.
- **New Apple device:** DK arrives via iCloud Keychain → unlock automatically.
- **Web browser or non-iCloud device ("Link with QR"):** new device creates an ephemeral X25519 key pair, registers a link request (`POST /api/link`, 5-minute TTL, returns short code) and shows a QR containing the request id + its public key. The signed-in iPhone scans it (Profile → Link a browser), shows "Allow Chrome on Mac to read your diary?" + Face ID, performs X25519 ECDH, sends DK encrypted to the derived key via the server. The new device decrypts it. Server only relays ciphertext.
- **Fallback:** "Enter recovery key" → derives KEK → unwraps the server-stored envelope.
- Lost all devices + lost recovery key = diary unreadable. Stated plainly in onboarding, the recovery key screen and the FAQ.

### 10.5 Sync protocol
- **Recently Deleted:** `trashedAt` (and a category's `unassignedIDs`) travel **inside the encrypted payload** like any other field, so the server can't tell a trashed item from a live one. Trash and restore are ordinary updates (last-writer-wins). The 30-day purge is a permanent delete: `deleted: true` tombstone, R2 blobs removed. A device that sees a tombstone never recreates the record.
- **Push:** `POST /api/sync/push` `{changes:[{id,type,ciphertext,nonce,clientUpdatedAt,baseVersion,deleted}]}` ≤ 200 changes / ≤ 1 MB per request. Server assigns a per-user monotonic `version`. Conflict (baseVersion behind server): **last-writer-wins by `clientUpdatedAt`**; loser returned so the client can update.
- **Pull:** `GET /api/sync/pull?since=<cursor>&limit=500` → changes after cursor + next cursor.
- **Blobs:** `PUT /api/blobs/photo/:photoId` (a photo's three renditions in one request, DECISIONS 190; the single `PUT /api/blobs/:id` remains, ≤ 4 MB, streamed to R2 via binding), `GET /api/blobs/:id` (streamed, `Cache-Control: private, max-age=31536000, immutable` — content is encrypted and immutable). Uploads max 2 concurrent; thumbnails first.
- **Real-time:** while the app is in the foreground (or web tab visible), it opens one WebSocket to `UserHub` (`/api/live`). After any accepted push, the Worker pings the user's `UserHub`, which broadcasts `{"cursor": N}` to that user's other connections; they pull. Uses Hibernation so idle sockets cost nothing. Socket closes in background.
- **When the iOS app syncs:** on launch/foreground (one pull), 2 s after the last local edit (debounced push), on WebSocket ping, and on `BGAppRefreshTask`. Exponential backoff with jitter on errors; honour `Retry-After`.
- **Request budget target:** ≤ 10 Worker requests per active user per day on average (log a DEBUG counter to verify).
- **First sign-in from guest mode:** all existing local records marked dirty and pushed in batches (progress bar "Encrypting and syncing 412 pages…").
- **Sign out:** stop sync, delete session + DK from this device; ask whether to keep local data.

### 10.6 Delete account (App Store 5.1.1(v) — must be in the app and on the web)
Profile → Account → **Delete account** → explainer sheet ("This permanently deletes your account and every entry, photo and task stored on our servers. This can't be undone.") → re-authenticate (Apple/Google/email code) → type `DELETE` → confirm.
Worker: delete all `records`, `blobs` + R2 objects under `u/<userId>/` (batched, via a Durable Object alarm if large), key envelopes, sessions, devices, accounts, user row; **revoke the Apple refresh token** via Apple's `auth/revoke` endpoint; Google: revoke token if stored; send a confirmation email; write only a hashed id + timestamp to `deletions_log`. Completes immediately for the user (server cleanup finishes within minutes).
App then asks: "Keep a copy of your diary on this iPhone (guest mode)?" Yes / Erase everything.
Web: same flow at `/app/settings/account`.

### 10.7 Quotas & rate limits (protect users and the free tier)
Use the Workers **rate-limiting binding** if available on the current plan (verify), else counters in `UserHub`/D1.
| Endpoint | Limit |
|---|---|
| email/start | 3 per email per 15 min; 10 per IP per hour; Turnstile on web |
| email/verify | 5 attempts per code; 20 per IP per hour |
| OAuth start/callback | 30 per IP per hour |
| sync push/pull | 120 per user per minute |
| blobs PUT | one request per photo (3 renditions): 600 per user per hour, 3,000 per day (DECISIONS 190); 4 MB per rendition |
| link requests | 10 per user per hour |
| invite tries (sign-in with an invite) | 10 per IP per hour |
| invites made | 30 per owner per day; ≤ 20 open |
| delete account | 3 per user per day |
Per-user storage quota: **1 GB of photos, 50,000 records** (friendly message when near). 429 responses include `Retry-After`.

---

## 11. Website + web app (Cloudflare Pages, free)

### 11.1 Stack
`/web`: **Astro** (static) + **React** islands + TypeScript + CSS custom-property tokens mirroring §3.2 + **Motion** for animation. Deployed by Cloudflare Pages from GitHub (root `web`, output `dist`). API calls are same-origin `/api/*`.

### 11.2 Marketing pages
Inspiration: **Calendly** (one crisp promise, single CTA, UI shown immediately), **Goodnotes** (real device imagery, warm paper tone, serif warmth, alternating feature rows), **Notion** (confident type, whitespace, readable FAQ). Paper light theme default + dark via `prefers-color-scheme`; headlines **Instrument Serif**; body `-apple-system, BlinkMacSystemFont, "Inter", system-ui, sans-serif`; glass via `backdrop-filter: blur(24px) saturate(160%)` with solid fallback; CSS aura blobs.
0. **Batch L overhaul:** the home page opens on a diary page (faint ruling, an Ink margin line, an ink stroke drawn under "kept.", the app's seasonal layer chosen in the browser by month and region) with the real web app behind the 3D iPhone; the illustrated month and the made-up personas are gone — the real calendar with a key to its marks, a strip of real screenshots ("Every screen, as it is"), "Make it yours" (avatars, looks, seasons, colours). Copy in `docs/WEBSITE_COPY.md`; nothing claimed that the build doesn't do.
1. **`/`** — glass sticky nav (logo · Features · How it works · Privacy · About · FAQ · **Sign in** · **Get started**, both to `/app`; full-screen glass menu on phones — owner, Batch H; story and copy in `docs/WEBSITE_COPY.md`, pages `/features`, `/how-it-works`, `/security`, `/about`, `/faq`, `/download`); hero "Your days, kept." + "A calendar diary for iPhone and the web. Encrypted so only you can read it." + CTAs "Join the TestFlight" (later App Store badge) / "Open in browser"; hero iPhone frame with a live HTML/CSS/Motion recreation of the calendar (month swipe, photo tile appears, half sheet rises; pauses for reduced motion); trust row "End-to-end encrypted · Works offline · On-device dictation · Open source · Made by Soul Archive Ltd"; alternating feature sections; privacy band ("Encrypted on your device." "No ads." "No tracking."); open-source band; FAQ (8+ incl. "Can you read my diary?", "What if I lose my phone?", "Do I need an account?"); footer with "Soul Archive Ltd · Registered in England and Wales · Company no. 16186654 · Registered office: 71-75 Shelton Street, Covent Garden, London, WC2H 9JQ" + Privacy · Terms · Support · GitHub.
2. `/privacy` (§14.1) · 3. `/terms` (§14.2) · 4. `/support` (FAQ + mailto support) · 5. `/open-source` · 6. `/changelog` · 7. `/delete-account` (explains how; links to the web app flow — useful for store listings) · 8. `/404` · 9. `/app` web app.
Every page: title, meta description, OG image, favicons, sitemap.xml, robots.txt (disallow `/app` and `/api`).

### 11.3 Web app (`/app`) — same UI/UX as iOS
- **Sign-in page:** the same three options (Apple / Google / email code with Turnstile). Then **Unlock**: "Scan with your iPhone" QR (default) or "Use recovery key"; optional "Trust this browser for 30 days".
- **No splash (Batch L):** `/app`'s first paint is the sign-in gate itself (static HTML: card, headline, a small inline spinner where the buttons go), and React replaces it in place without re-animating. A browser that has never signed in shows the real sign-in page at once while the session check runs underneath; one that was signed in (`localStorage` hint `folio.signedIn` = "1", set on sign-in, removed on sign-out or a refused session — only a hint, the cookie decides) shows the gate with "Opening your diary…". Only the installed app (`display-mode: standalone`) keeps a short launch screen: the mark alone, like iOS.
- **Layout ≥ 1024 px:** left glass sidebar (Calendar · Journal · To-do · Profile; avatar at bottom), centre month grid with identical cell states, right day panel; composing opens a right-side glass sheet so the calendar stays visible. **< 768 px:** identical to iOS — floating glass tab bar, bottom-drawer composer.
- **Search (Batch J):** "Search" in the sidebar and the phone tab bar, "/" or ⌘K: the same words, filters and highlights as §6.17, run in memory over the diary this tab has already decrypted; results open the entry or task sheet. Nothing is indexed on the server or stored in the browser.
- **Installable (Batch J):** `manifest.webmanifest` (id/start/scope `/app`, standalone, paper colours, 192/512 icons + a maskable one rendered from the mark by `scripts/pwa-icons.swift`), Apple web-app meta tags, and a service worker (`/app-sw.js`, scope `/app`) that caches **only the app shell** — the `/app` page (network first) and hashed `/_astro`, fonts and icons (cache first). It never touches `/api`, so no diary data, ciphertext or photo is cached; opened offline, the installed app shows its "You're offline" gate. "Install on your phone" in the web app's Profile (Chrome's install prompt when offered, plus steps for Safari, Android and desktop) and on the website's Download page.
- **Memories (Batch J):** mood picker in the composer (same five glyphs as SVG), mood on cards and detail, On this day card in the day panel, and **Year** as the Journal's third view (‹ › years, Mood | Category).
- **Features:** calendar, day panel, entries (create/edit/delete, photos upload/view, all encrypted client-side), tasks (same 1.2 s + undo rules), categories, filters, theme, writing font, devices list, sign out, delete account. Dictation and ✦ are iPhone-only ("Available in the iPhone app").
- **Parity with the iPhone (Batch L):** calendar cells use the iPhone's marks exactly (§6.2: today = accent number + 1.5 px accent outline; selected = accentStrong square, white number, a 3 px accent frame on a photo; tasks = one small top-right mark, hollow ring while any is open, green check when all are done). To-do has the iPhone's groups (Overdue · Today · Tomorrow · This week · Later · No date; folds remembered in `localStorage` `folio.todoClosed`), rows show subtasks "1/3", a bell with the reminder time and repeat arrows, and quick add reads the same natural dates and times as §6.7 (`web/src/app/lib/quickadd.ts`, tested with the iPhone's own cases) with a live chip above the bar; on phones To-do shows only the bar's +. Journal month headers are the iPhone's (small caps, count, hairline, chevron) and fold (this and last month open; `folio.journalFolds`); Timeline / Photos / Year are icon toggles.
- **Welcome (Batch L):** the first time an account opens in a browser, a glass card in the onboarding's voice: "Your days, kept." with a month assembling → (accounts with no name yet) "What should we call you?" + the 24 Folio avatars → Your look (Light / Dark / Match device) → Find your way (calendar, New entry / N / drop photos, Search / and ?, dictation on iPhone). Skippable; remembered per account in this browser (`folio.welcomed.<userId>`); Profile → Help → Show the welcome again.
- **Keyboard (Batch L):** N new entry (selected day) · T new task · / or ⌘K search · 1–4 tabs · arrows move days in the grid · [ ] month · G today · ⌘/Ctrl-Enter saves in the composer · Esc closes · ? shows the list. Off while typing, with a modifier, or with a sheet, menu or the welcome open.
- **Drag and drop (Batch L):** photos dropped on a calendar day open a new entry for that day with them attached; while the composer is open, photos dropped anywhere join it (same 10-photo limit and JPEG preparation as the picker).
- **Your data (Batch L):** Export as JSON + photos — `Folio Export.json` (the iPhone's shape) and `Folio Photos/` in one zip written in the tab (`lib/zip.ts`, stored, no library), optional Recently Deleted; **Export PDF** — the §6.21 book (cover, a page per month, entries with photos and the day's tasks, page numbers where the browser supports `@page` margin boxes) rendered into a print-only layer at A5 and handed to the browser's print window ("Save as PDF"). Nothing is uploaded. **Help:** What do the marks mean? · Keyboard shortcuts · Show the welcome again · Support & FAQ · Contact support. **About:** Website, Privacy Policy, Terms, Cookies and storage, Acceptable use, Accessibility, Company details, Open source.
- **Editor:** Tiptap restricted to §5.1 styles, serialising via the shared Markdown fixtures.
- **Real-time:** WebSocket to `/api/live` while the tab is visible; pull on focus; optimistic updates with rollback.
- **Photos:** synced display and full renditions are JPEG so every browser can show them (DECISIONS 193). Delete account (`/app/settings/account`) runs as its own page without unlocking the diary (DECISIONS 199).
- **Storage:** session cookie (strictly necessary); diary content only in memory (or encrypted IndexedDB if "Trust this browser"); UI prefs in localStorage. No other cookies → **no cookie banner needed** (cookie use explained in the privacy policy).
- **Security headers** (`web/public/_headers` and Worker responses; Batch L: API responses also send `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'` and `Cross-Origin-Resource-Policy: same-origin`; audit in `docs/SECURITY_AUDIT.md`): strict CSP (`default-src 'self'`; scripts self + `challenges.cloudflare.com` for Turnstile; connect-src self + `wss://folio.devilsense.com`; img-src self blob: data:; fonts self-hosted only (`font-src 'self'`; Batch L: no Google Fonts or other third-party requests anywhere except Turnstile on the email step); `frame-ancestors 'none'`), HSTS (preload), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`, `Cross-Origin-Opener-Policy: same-origin`.

---

## 12. App Store & legal compliance (all true before submission)

**App Review**
- [ ] 2.1 Complete; no placeholder/beta text; every button works. Review notes: "Account optional — tap 'Not now' to use everything without signing in. To test sync, choose Continue with email, enter review@devilsense.com and the 6-digit code given in these notes." Builder implements this as one allowlisted demo address whose fixed code is a Worker secret, rate-limited, and switchable off after approval.
- [ ] 4.8 Sign in with Apple offered alongside Google (equivalent prominence, Apple first).
- [ ] 5.1.1 Privacy policy link in App Store Connect and in-app. Purpose strings §7; prompts only in context. Not forced to sign in to use non-account features (guest mode).
- [ ] 5.1.1(v) Account deletion in-app (§10.6), including Sign in with Apple token revocation.
- [ ] 5.1.2 No data shared with third parties beyond processors (Cloudflare hosting, Resend email delivery).
- [ ] `requestReview` never automatic.

**Privacy**
- [ ] `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, no tracking domains, collected data types per the label below, required-reason APIs declared (UserDefaults `CA92.1`, file timestamp `C617.1`, disk space `E174.1` if used) — verify current codes.
- [ ] App Store privacy label: **Contact Info → Email Address** (App Functionality, linked to user, not tracking). For end-to-end encrypted user content, follow Apple's current App Privacy definitions (check whether E2E-encrypted data that we cannot read must be declared) and record the answer in DECISIONS.md.
- [ ] GPS EXIF stripped; content hidden in app switcher; no content in logs or crash reports.

**Other**
- [ ] `ITSAppUsesNonExemptEncryption`: the app uses only standard OS encryption (CryptoKit) for data protection → generally exempt; confirm with Apple's current export-compliance questions and record in DECISIONS.md.
- [ ] Age rating questionnaire → lowest rating (no user-to-user content).
- [ ] EU DSA: Soul Archive Ltd declared as **trader**.
- [ ] Google OAuth consent screen: app name, logo, privacy + terms URLs, authorised domain `devilsense.com`, scopes `openid email profile`.
- [ ] Accessibility Inspector clean on main screens.
- [ ] Works offline, in airplane mode, signed out, after account deletion.
- [ ] "© 2026 Soul Archive Ltd".

---

## 13. Secrets & security rules

1. **Nothing secret ships in a client.** The iOS app and website contain only public identifiers (bundle ID, Google iOS/web client IDs, Apple Services ID, Turnstile *site* key). These are designed to be public.
2. **Server secrets** (Apple Sign in `.p8` private key + key ID + team ID, Google client secret, Resend API key, Turnstile secret, auth secret, OTP pepper, refresh-token encryption key, review-account code) are stored **only** with `wrangler secret put` in Cloudflare's encrypted secret store. The builder asks the owner to paste each one into the terminal command when needed and **never writes them to any file**.
3. **Local development** uses `wrangler dev` with secrets in `api/.dev.vars`, which is git-ignored, never committed, never copied anywhere, and listed in `.gitignore`, `.dockerignore` and `.cfignore`. Use *test* OAuth clients for local dev where possible.
4. **No `.env` files in the repo at all.** `.gitignore` covers `.env*`, `.dev.vars*`, `*.p8`, `*.pem`, `*.key`.
5. **Secret scanning:** `gitleaks` pre-commit hook (installed in Phase 0) + GitHub secret scanning and **push protection** enabled + a CI job running gitleaks on every push.
6. **Dependencies:** Dependabot on `/api` and `/web`; lockfiles committed; no packages with install scripts unless reviewed; `npm audit` in CI.
7. **Server hygiene:** zod validation on every input; size limits on every body; parameterised D1 queries only; constant-time comparisons for codes/tokens; no request bodies or ciphertext in logs; generic error messages to clients; every query scoped by `userId` from the session (never from the request body); IDs are UUIDv4/v7.
8. **Transport:** HTTPS only, HSTS; WebSocket upgrade requires a valid session.
9. **iOS:** Keychain for session + DK; `NSFileProtectionComplete` for the SwiftData store and photo files; App Transport Security default (no exceptions); certificate pinning not used (avoids outages).
10. **Security review** with `/vibesec` at the end of every backend/web phase; findings fixed before moving on.

---

## 14. Legal pages (drafts — owner must have them reviewed; not legal advice)

**Batch L:** pages are `/privacy` (rewritten from the D1 schema: every stored item with purpose and retention, lawful bases, processors and transfers, UK/EU/India rights, ICO/EU/India complaints, 18+ accounts), `/terms` (18+, acceptable use, ending, changes, consumer protections), `/cookies` (every cookie and storage item; no banner — all strictly necessary), `/refunds` (free, nothing to buy), `/acceptable-use`, `/accessibility` (WCAG 2.2 AA statement), `/imprint` (company details) — all linked in every footer and in the app's Profile → About; the web app's Profile → About links the same. Analysis, sources, risk register and owner checklist: `docs/COMPLIANCE.md`.

### 14.1 Privacy Policy — plain English
- Controller: Soul Archive Ltd (no. 16186654), registered office above; privacy@devilsense.com.
- **Without an account:** everything stays on your device; we receive nothing.
- **With an account we store:** your email address and sign-in provider IDs (to let you sign in), device names and last-seen times (so you can manage devices), and your diary **only in end-to-end encrypted form** that we cannot read. We cannot recover your diary without your devices or recovery key.
- Processors: Cloudflare (hosting, database, storage — data may be processed in Cloudflare's global network), Resend (sending sign-in codes). Apple and Google (only if you choose to sign in with them).
- Dictation and Intelligence run on your iPhone; audio and text are not sent to us.
- Cookies: one strictly necessary session cookie on the web app; no analytics or advertising cookies.
- Retention: account data until you delete your account; deletion is immediate with server cleanup completing within 30 days at most (backups); items you delete go to Recently Deleted on your devices and are permanently deleted after 30 days (or sooner if you empty it); support emails kept up to 24 months.
- Your UK GDPR / EU GDPR rights (access, export — use the in-app export —, deletion, complaint to the ICO).
- Children: not directed at under-13s.
- Changes + effective date.

### 14.2 Terms of Use
Licence to use; open-source code licence ≠ trademark/name licence; you own your content; you're responsible for your recovery key; acceptable use; service "as is"; liability limited as far as law allows; we may suspend abusive accounts; governing law England & Wales; contact.

### 14.3 Support FAQ topics
Can you read my diary? · What is the recovery key? · Lost my phone · Using Folio on the web (QR unlock) · Sync not working · Dictation/✦ not showing · Sign-in code not arriving · Deleting my account · Contact.

---

## 15. Performance & free-tier budget

### 15.1 App performance
Cold launch to interactive calendar < 400 ms (greeting runs while data loads). 120 fps paging/scrolling; thumbnails decoded off-main and cached (`NSCache`). Composer opens < 150 ms. 10,000 entries + 5,000 photos stay smooth (DEBUG generator). Web: Lighthouse ≥ 95 on marketing pages.

### 15.2 Free-tier budget (Cloudflare free plan as of 2026 — verify current numbers)
Workers 100k requests/day · D1 5 GB, 5M rows read/day, 100k rows written/day · Durable Objects (SQLite) 100k requests/day · R2 ~10 GB storage · Pages static requests unlimited.
Design targets: ≤ 10 requests per active user per day; photo ≤ 600 KB; thumbnails ≤ 25 KB. Expected: free up to roughly 2–3k daily active users; at ~10k DAU move to Workers Paid ($5/month, 10M requests included) — no code changes needed. Usage is watched in the Cloudflare dashboard (Workers, D1, R2 and Durable Objects analytics) — there is no admin endpoint in the API (DECISIONS 176).

---

## 16. Repository layout
```
folio/
├─ CLAUDE.md               # rules → docs/SPEC.md
├─ docs/SPEC.md  docs/DECISIONS.md  docs/PHASES.md  docs/APPSTORE.md
├─ shared/                 # markdown-fixtures.json, crypto-vectors.json, api-types (OpenAPI or zod-generated JSON schema)
├─ ios/  project.yml, Folio/{App,DesignSystem,Models,Features/*,Services/{Sync,Auth,Crypto,Dictation,Intelligence,Export},Resources}, FolioTests/
├─ api/  wrangler.toml (no secrets), src/{index.ts,routes/*,auth/*,sync/*,hub/UserHub.ts,lib/*}, migrations/*.sql, test/
├─ web/  Astro site + /app React islands
├─ .github/workflows/      # gitleaks, tests, npm audit
├─ .gitignore  LICENSE (Apache-2.0, © Soul Archive Ltd)  README.md
```
`CLAUDE.md`: "Read docs/SPEC.md before any task. Follow §0 and §13. Use Context7 for any iOS 26+, Cloudflare, Better Auth or OAuth API. Never write secrets to files. Update docs/PHASES.md and docs/DECISIONS.md each phase. End every phase with the Phase Report (§18)."

---

## 17. Later (don't build until asked)
alternate icons · Journaling Suggestions · passkeys.

---

## 18. Phase Report (end of every phase, exact shape)
```
PHASE X REPORT
Built: (bullets)
Files changed: (count + key files)
Screenshots / recordings: (paths, light + dark)
Tests: (passed/failed)
Security: (secrets check result; /vibesec findings + fixes, if run)
Deviations from SPEC: (none / list with reason)
Manual steps needed from the owner: (numbered, plain language, one action each)
Open questions for the Architect: (numbered)
Known issues: (numbered)
Next phase ready: yes/no
```
