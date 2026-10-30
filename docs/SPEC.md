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
  First launch only: Welcome (3 pages) → Name → Sync choice (Apple / Google / Email / Not now)
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
2. **Monochrome + one accent** ("Ember"). Colour comes from your content — photos and category colours.
3. **Content as colour.** Day cells with a photo show it as a tiny rounded thumbnail. The app's signature.
4. **Big confident numerals.** Dates are typography.
5. **The sheet keeps context.** Lists and composers live in bottom sheets over the calendar.
6. **Glass sits on light.** Glass floats over a soft, slowly drifting colour "aura" at 10–18% opacity — never a rainbow.
7. **A greeting with a summary** with inline SF Symbols.
8. **Floating pill controls** with depth — for primary actions and chips only. Headers stay compact: a smaller in-content title that becomes a slim glass pill in the top bar on scroll; no extra full-width containers (Batch I).

### 3.2 Colour tokens (asset catalog light/dark + Swift `Color` tokens; never raw hex in views)
| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#0A0A0C` | `#F5F3EF` | Background |
| `bgElevated` | `#141418` | `#FFFFFF` | Cards when Reduce Transparency is on |
| `ink` | `#F4F4F5` | `#16161A` | Primary text |
| `inkSecondary` | ink @ 62% | ink @ 60% | Secondary text |
| `inkTertiary` | ink @ 36% | ink @ 34% | Placeholders, out-of-month days |
| `hairline` | `#FFFFFF` @ 8% | `#000000` @ 7% | Separators |
| `ember` | `#FF7A45` | `#F0602A` | Today, selection, primary actions |
| `done` | `#7ED69B` | `#2FA35A` | Completed marks |
| `danger` | `#FF5A5F` | `#D93A3F` | Destructive actions |
| `aura1/2/3` | `#FF7A45` / `#B65CFF` / `#3D7BFF` | `#FFB38F` / `#D9B8FF` / `#A9C6FF` | Aura blobs |

**Category palette** (12, tuned light/dark): Ember, Coral, Rose, Plum, Violet, Indigo, Ocean, Teal, Sage, Olive, Sand, Graphite. Labels on category colours auto-switch dark/light to pass WCAG AA.
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
Spacing 4/8/12/16/20/24/32/40; side margin 20. Radii: day cell 12, card 22, chips/buttons capsule. Use `ConcentricRectangle` for nested shapes in glass. Glass via the system only: `.glassEffect(.regular, in:)`, `.regular.interactive()` for tappables, `.buttonStyle(.glass)` / `.glassProminent` tinted `ember`; neighbours inside `GlassEffectContainer`. Material + border only as the Reduce Transparency fallback.

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
SF Symbols only. Photos: radius 22 with 1 px inner hairline. Empty states: one large SF Symbol on glass + one sentence.

### 3.9 Accessibility
≥ 44 pt hit areas · day cells read e.g. "Tuesday 14 October, 2 entries, 1 task done" + rotor "Days with entries" · Reduce Transparency → `bgElevated` cards · Increase Contrast → stronger hairlines/secondary text · Dynamic Type to AX5 (calendar switches to week rows at AX sizes) · colour never the only signal.

### 3.10 App icon
Layered Liquid Glass icon from **Icon Composer** (light/dark/tinted). Concept: rounded "page" glyph + small ember dot on deep ink. Builder makes a placeholder until supplied.

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
Horizontal paging with parallax, page dots, Skip (top-right) jumps to step 4.
1. **"Your days, kept."** — animated month grid assembling tile by tile with sample photo tiles.
2. **"Write for any day."** — an old date flips into view; "Move your old diaries in."
3. **"Private by design."** — lock glyph; "Encrypted on your iPhone before it syncs. Not even we can read it."
4. **Name** — "What should we call you?" (optional; Continue / Skip).
5. **Sync choice** — headline "Keep your diary in sync?" sub "Use Folio on the web and on a new iPhone. Encrypted end to end."
   - **Continue with Apple** (system `SignInWithAppleButton`, `.black`/`.white` style per appearance, placed first per Apple HIG)
   - **Continue with Google** (white button with the official Google "G" mark per Google's branding guidelines)
   - **Continue with email** → email field → 6-digit code screen (auto-fill from Mail via `.textContentType(.oneTimeCode)`, resend after 30 s, errors inline)
   - **Not now — keep it on this iPhone** (text button). Guest mode: everything works offline; Profile offers sign-in later.
   - Footer: "By continuing you agree to the Terms and Privacy Policy" (links).
6. **Recovery key** (new account only) — §10.4. Must be saved before continuing.
7. **Unlock** (existing account, new device) — automatic if the key is in iCloud Keychain; otherwise "Scan from your other device" (shows QR) or "Enter recovery key".
8. → Greeting intro → **Tour** (§6.15).
No permission prompts during onboarding.

### 6.2 Calendar tab (opening screen)
Over `AuraBackground`:
- **Header:** month `title1` + year `title2` `inkSecondary`; tapping opens Jump sheet (chevron glyph). Right [G] group: Filter (category menu) and **Today** pill (morphs in only when off today/current month). Small sync indicator dot (only shown while syncing or on error).
- **Weekday row** `caption` `inkTertiary`, locale first weekday (Profile override).
- **Month grid [G panel, r22]:** infinite horizontal paging (`.scrollTargetBehavior(.paging)`, `scrollPosition(id:)`, lazily extended ±240 months, extend near edges). 6×7, gap 6.
  - Cell states (one zone per meaning, so marks never overlap — Batch I): default · out-of-month (`inkTertiary`, tap jumps month) · today (ember bold number + 1.5 pt ember outline; on a photo tile, an ember pill behind the number) · selected (ember rounded square, white number, spring; on a photo, a 3 pt ember frame) · **entry with photo → latest photo thumbnail fills the cell**, `micro` white number top-left, "+2" badge bottom-right if more · entry without photo → up to 3 category dots under the number · tasks → one small mark in the top-right corner, inside the cell: a hollow ring while any is open, a green check once all are done · filter active → non-matching markers at 15%.
  - "What do the marks mean?" key: Profile → Help, and a long-press on the weekday row (VoiceOver action too).
  - Long-press day → New entry / New task for this day.
- **Day panel:** "Saturday, 25 October" `title2` + [G] mini "+". Entries section (cards: 64 pt photo, title, 2-line preview, category chip, time) → detail via zoom. Tasks section (checkbox toggles in place; completed shown checked, struck, 50% — they stay). Empty: "Nothing here yet." + Write · Add task.
  - Scrolling the panel up collapses the grid to the selected week (swipeable week strip); scroll to top or tap title to expand. Fully interactive (tracks finger). It always comes to rest fully open or fully collapsed: the release uses the system's projected (velocity-aware) target, and any scroll that stops in between (an interrupted deceleration, content changing height) settles to the nearer end. Only the grid's height, offset and fades read the drag progress (Batch I).
  - The day panel runs down to the tab bar: only the round "+" floats over it, and the panel's last row can scroll fully clear of the button.
  - After a full close with unsaved writing, a "Continue your draft" pill floats beside the "+": tap to reopen the draft's composer with it restored; swipe it away to discard the draft (Batch I).

### 6.3 Jump sheet
`.medium` glass sheet: horizontal snapping year strip (1900 → current+10, selected in `display`), 4×3 month capsules (dot if month has entries), [G] "Go to today". Jump = quick fade+scale.

### 6.4 Composer (half sheet)
- `.presentationDetents([.medium, .large])`, `.presentationBackgroundInteraction(.enabled(upThrough: .medium))` — the calendar stays visible and tappable; tapping another day moves the entry to it (haptic tick, date pill animates). Drag indicator visible; `.interactiveDismissDisabled(hasUnsavedText)`.
- Top bar: Cancel · date pill [G] (compact DatePicker popover + optional time) · **Save** (`.glassProminent` ember; disabled until there's content).
- Title (`title2`, "Title"); rich body (writing font; "What happened today?" / past date: "What do you remember about this day?").
- Keyboard toolbar [G]: Aa (format popover) · Photo (`PhotosPicker`, up to 10, no permission) · Camera (asks at use) · Category · Mic (§8) · ✦ (§9, only if available).
- Photo strip (reorder by long-press, × remove). Category chips with inline "+".
- Draft autosave every 2 s locally; "Continue your draft?" on reopen. Cancel with changes → "Discard this entry?" / Keep writing for a new entry, "Discard changes?" / Keep editing for an existing one; the sheet closes only after the dialog has gone (Batch I).
- The sheet reads as its own layer: the screen behind dims slightly (more toward the sheet), a stronger material with a fine highlight along the top edge, in light and dark.
- Checklists: tapping a box ticks or unticks it directly; Return continues the list; Return on an empty item ends it. Same in the web editor.

### 6.5 Entry detail
Zoom-in from the card. Photo carousel (4:3, paging, pinch to full-screen) · date line `caption` · category chip · title · rendered body (line height 1.45). Toolbar: Edit (composer `.large`) · Share · ••• Change date / Duplicate / Delete (to Recently Deleted, §5.2). Share offers: **Share as text** (a plain `String` with a subject and preview, which every app accepts — Messages, WhatsApp, Notes, Mail), **Share text and photos**, and **Share as image** — one card, or for entries too long for a card a choice of "Single card" / "All pages (N)": numbered 1/N story-sized images (1080 × 1920) with the text flowing across them so nothing is cut (Batch I). Footer strip **"On this day"** with the subtitle "You wrote on 29 October in 2025" when applicable.

### 6.6 Journal tab
Compact title "Journal" with the *Timeline* / *Photos* toggle beside it; category chips [G]; "Past day" in the top bar. Timeline: month headers in a lighter style than the cards (small-caps month, count, hairline, chevron — no card), cards with cover photo (16:9, title over gradient) or text cards. Months fold: this month and last month open by default, older months closed; tap to open or close; the choice is remembered (Batch I). Photos: 3-column masonry of all photos. "Write for a past day" button opens composer with date picker. Empty: "Your journal is empty. Tap + to write your first page." Search is not shown until built.

### 6.7 To-do tab
Compact title, category chips, and a date button in the top bar that shows one date's tasks only. **Active** in collapsible groups (state persisted): Overdue (ember) · Today · Tomorrow · This week (the next five days) · Later · No date; within a group by date, then time, then drag order. Tasks can be dragged to reorder among tasks of the same date (a drop onto another date springs back). Tapping a task opens it for editing; long-press keeps the menu. Scrolling or tapping outside the quick-add bar puts the keyboard away (Batch I). **Completed** (collapsible "Completed · 12", state persisted) by `completedAt` desc. Row: 26 pt circular checkbox in category colour · title · 1-line notes · date/time chip.
**Complete flow:** tap → fill + check + strike + haptic → stays **1.2 s** → moves to Completed; undo toast [G] 4 s; tapping again during 1.2 s cancels. Untick in Completed → back instantly.
Swipes: leading Complete/Uncomplete; trailing Delete (to Recently Deleted, §5.2) · Edit · Date (Today / Tomorrow / Next week / Pick / Remove). Quick-add bar [G] above tab bar ("Add a task…") that understands natural dates and times at the start or end of the line — today, tonight, tomorrow, day after tomorrow, in/after N days|weeks|months, next week/month, (this) weekend, [on|this|next] Monday, on 5 Nov / 5th of November / November 5 / 5/11 (day first; month first in the US), times like 6pm, 6:30 pm, 18:30, at 7, noon, morning/afternoon/evening — with a live chip ("Tomorrow · 18:00") above the bar before saving (Batch I). "Today's papers" stays as typed. A bare "at 7" is the next 7 o'clock that hasn't passed; a time alone is today, or tomorrow once passed. Empty Active → "All clear." with `checkmark.seal`.

### 6.8 Task composer (`.medium` sheet)
Title (required) · Notes · Date toggle → graphical DatePicker · Time toggle (if date) · Category chips · Save. Existing task: Delete at bottom (to Recently Deleted, §5.2).

### 6.9 Profile tab
Inset-grouped glass sections:
- **Header card [G]:** profile picture, name (tap to edit), "Writing since March 2019 · 412 pages". No streaks anywhere. Tap the picture → **Choose photo** (PhotosPicker, then a circular crop: drag to move, pinch to zoom; saved as a 256 px JPEG) or **Folio avatars** (24 original "page spirits" — a little page with a folded corner, a face and the ember dot, each with its own palette and personality; vector art generated with the web's copies by `scripts/avatars/generate.py`) · Remove picture. Without one, the monogram. The picture syncs encrypted with the settings and shows in Profile, the greeting, Devices ("This device") and the web app (sidebar, Profile — where a Folio avatar can also be chosen —, Devices) (Batch I).
- **Your archive** 2×2 tiles: Entries · Photos · Days written on · Tasks done (tap → filtered tab).
- **Account:**
  - Guest: "Sync & web access" card with the three sign-in buttons (same as onboarding step 5).
  - Signed in: email / provider icon · Sync status (Up to date · Syncing… · Offline — will sync later · Error, tap for detail) · last synced · "Sync now" · **Devices** (model + OS such as "iPhone 15 Pro · iOS 27.1" or "Chrome on macOS", date added, last seen, "This device"; rename any device — the name is encrypted with the Data Key; "Sign out" each, "Sign out other devices"; DECISIONS 189) · **Recovery key** (Face ID/passcode gated "Show recovery key") · **Link a browser or device** (shows QR, §10.4) · **Sign out** (asks: keep diary on this iPhone or remove it) · **Delete account** (§10.6, `danger`).
- **Categories** → manager (§6.10).
- **Appearance:** Theme, Writing font, First day of week.
- **Writing:** Default category · Show photo tiles on calendar.
- **Dictation & Intelligence** (§8–9) with availability explanation.
- **Privacy & Security:** Hide content in app switcher · Face ID lock (later; hidden until built).
- **Your data:** **Recently Deleted · N** (§5.2) · Export as JSON + photos zip (decrypted, local; "Include Recently Deleted" toggle, off by default) · Export PDF (later; hidden) · Erase data on this iPhone (also empties Recently Deleted).
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

---

## 7. Permissions — only at the moment of use
| Permission | When | Purpose string |
|---|---|---|
| Photos | Never (PhotosPicker) | — |
| Camera | Tap Camera | "Folio uses the camera only when you choose to take a photo for an entry." |
| Microphone | First tap of Mic | "Folio uses the microphone only while you dictate. Audio is processed on your iPhone and never stored or sent anywhere." |
| Speech recognition | Only if the Speech API requires it (verify) | "Folio turns your voice into text on your iPhone. Nothing is sent to a server." |
| Face ID | Showing recovery key; app lock (later) | "Folio uses Face ID to protect your recovery key and diary." |
| Notifications | Later, when user taps "Remind me" | system |
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
- **Email:** `POST /api/auth/email/start {email}` → 6-digit code, hashed (SHA-256 + server pepper), 10-min expiry, max 5 attempts, then invalidated → `POST /api/auth/email/verify`. Identical response whether or not the email exists (no account enumeration).
- **Linking:** same verified email across providers links to one user (Apple private-relay emails won't match — that's fine). Profile shows linked providers.
- **Sessions:** 256-bit random opaque token; only its SHA-256 stored in D1; 30-day sliding expiry; per-device row (name, platform, last seen). iOS: Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, not synchronizable. Web: `__Host-folio_session` cookie, `HttpOnly; Secure; SameSite=Lax; Path=/`. CSRF: SameSite + Origin check on all state-changing requests.

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
| delete account | 3 per user per day |
Per-user storage quota: **1 GB of photos, 50,000 records** (friendly message when near). 429 responses include `Retry-After`.

---

## 11. Website + web app (Cloudflare Pages, free)

### 11.1 Stack
`/web`: **Astro** (static) + **React** islands + TypeScript + CSS custom-property tokens mirroring §3.2 + **Motion** for animation. Deployed by Cloudflare Pages from GitHub (root `web`, output `dist`). API calls are same-origin `/api/*`.

### 11.2 Marketing pages
Inspiration: **Calendly** (one crisp promise, single CTA, UI shown immediately), **Goodnotes** (real device imagery, warm paper tone, serif warmth, alternating feature rows), **Notion** (confident type, whitespace, readable FAQ). Paper light theme default + dark via `prefers-color-scheme`; headlines **Instrument Serif**; body `-apple-system, BlinkMacSystemFont, "Inter", system-ui, sans-serif`; glass via `backdrop-filter: blur(24px) saturate(160%)` with solid fallback; CSS aura blobs.
1. **`/`** — glass sticky nav (logo · Features · How it works · Privacy · About · FAQ · **Sign in** · **Get started**, both to `/app`; full-screen glass menu on phones — owner, Batch H; story and copy in `docs/WEBSITE_COPY.md`, pages `/features`, `/how-it-works`, `/security`, `/about`, `/faq`, `/download`); hero "Your days, kept." + "A calendar diary for iPhone and the web. Encrypted so only you can read it." + CTAs "Join the TestFlight" (later App Store badge) / "Open in browser"; hero iPhone frame with a live HTML/CSS/Motion recreation of the calendar (month swipe, photo tile appears, half sheet rises; pauses for reduced motion); trust row "End-to-end encrypted · Works offline · On-device dictation · Open source · Made by Soul Archive Ltd"; alternating feature sections; privacy band ("Encrypted on your device." "No ads." "No tracking."); open-source band; FAQ (8+ incl. "Can you read my diary?", "What if I lose my phone?", "Do I need an account?"); footer with "Soul Archive Ltd · Registered in England and Wales · Company no. 16186654 · Registered office: 71-75 Shelton Street, Covent Garden, London, WC2H 9JQ" + Privacy · Terms · Support · GitHub.
2. `/privacy` (§14.1) · 3. `/terms` (§14.2) · 4. `/support` (FAQ + mailto support) · 5. `/open-source` · 6. `/changelog` · 7. `/delete-account` (explains how; links to the web app flow — useful for store listings) · 8. `/404` · 9. `/app` web app.
Every page: title, meta description, OG image, favicons, sitemap.xml, robots.txt (disallow `/app` and `/api`).

### 11.3 Web app (`/app`) — same UI/UX as iOS
- **Sign-in page:** the same three options (Apple / Google / email code with Turnstile). Then **Unlock**: "Scan with your iPhone" QR (default) or "Use recovery key"; optional "Trust this browser for 30 days".
- **Layout ≥ 1024 px:** left glass sidebar (Calendar · Journal · To-do · Profile; avatar at bottom), centre month grid with identical cell states, right day panel; composing opens a right-side glass sheet so the calendar stays visible. **< 768 px:** identical to iOS — floating glass tab bar, bottom-drawer composer.
- **Features:** calendar, day panel, entries (create/edit/delete, photos upload/view, all encrypted client-side), tasks (same 1.2 s + undo rules), categories, filters, theme, writing font, devices list, sign out, delete account. Dictation and ✦ are iPhone-only ("Available in the iPhone app").
- **Editor:** Tiptap restricted to §5.1 styles, serialising via the shared Markdown fixtures.
- **Real-time:** WebSocket to `/api/live` while the tab is visible; pull on focus; optimistic updates with rollback.
- **Photos:** synced display and full renditions are JPEG so every browser can show them (DECISIONS 193). Delete account (`/app/settings/account`) runs as its own page without unlocking the diary (DECISIONS 199).
- **Storage:** session cookie (strictly necessary); diary content only in memory (or encrypted IndexedDB if "Trust this browser"); UI prefs in localStorage. No other cookies → **no cookie banner needed** (cookie use explained in the privacy policy).
- **Security headers** (`web/public/_headers` and Worker responses): strict CSP (`default-src 'self'`; scripts self + `challenges.cloudflare.com` for Turnstile; connect-src self + `wss://folio.devilsense.com`; img-src self blob: data:; fonts Google Fonts; `frame-ancestors 'none'`), HSTS (preload), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`, `Cross-Origin-Opener-Policy: same-origin`.

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
Task notifications · Search (on-device, decrypted locally) · Widgets · Face ID app lock · PDF export · alternate icons · On-this-day · Year in Pixels · scan paper diaries (VisionKit + on-device text recognition) · Journaling Suggestions · App Intents/Shortcuts · Share extension · passkeys.

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
