# Folio — Phases

The roadmap. Each phase ends with a Phase Report (SPEC §18) and waits for the owner's go-ahead before the next one starts. Skills to use per phase are in `CLAUDE.md`.

Status key: ✅ done · 🟡 in progress · ⬜ not started

| # | Phase | Scope (SPEC refs) | Status |
|---|---|---|---|
| 0 | Setup | Repo layout, CLAUDE.md, docs, security guardrails (§13.4–13.6), XcodeGen project, empty app, LICENSE, README, first push | ✅ |
| 1 | Design system, greeting, privacy cover | Colour tokens, category palette, type scale, spacing, glass components, `AuraBackground`, toast, motion + haptics, accessibility fallbacks, DEBUG Design Gallery, greeting intro, app-switcher cover (§3, §4) | ✅ |
| 2 | Data + crypto core | SwiftData models, `DayKey`, sync fields, `@Observable` store, `MarkdownCodec` + shared fixtures, image pipeline, `PreviewData`, `FolioCrypto` + shared vectors, recovery key, X25519 link handshake, greeting summary on real data (§5, §10.3, §10.4) | ✅ |
| 3 | Tabs + Calendar | Native TabView shell, floating "+", Calendar tab, endless month paging, all cell states, filter, Today pill, day panel, collapse to week, Jump sheet, long-press menus, VoiceOver + rotor (§2, §6.2, §6.3, §15.1) | ✅ |
| 4 | Composer + entry detail | Composer half sheet, rich text, photos, drafts, entry detail with zoom (§5.1, §6.4, §6.5) | ✅ |
| 5 | To-do | To-do tab, task composer, complete/undo flow, quick-add (§6.7, §6.8) | ✅ |
| 6 | Journal + Categories | Journal tab (Timeline / Photos), categories manager (§6.6, §6.10) | ✅ |
| 7 | Onboarding + tour + Profile | Welcome pages, name, sync choice UI, recovery key + unlock screens, TipKit tour, Profile tab (guest mode), iPad split view (§6.1, §6.9, §6.13, §6.15, §6.16) | ⬜ |
| 8 | Dictation + AI | SpeechAnalyzer dictation overlay, Foundation Models ✦ menu, permission explainers (§6.11, §6.12, §7, §8, §9) | ⬜ |
| 9 | Backend | Worker, D1 schema, R2, `UserHub`, Better Auth (Apple/Google/email OTP via Resend), sync, blobs, linking, delete account, rate limits, admin usage (§10, §13, §15.2) | ⬜ |
| 10 | iPhone sign-in + sync | Sign-in flows, Keychain, DK + recovery key, sync engine, live socket, background refresh, QR device linking, delete account in-app (§10.2–10.6) | ⬜ |
| 11 | Website | Astro marketing site, legal pages, support/FAQ, headers, SEO (§11.1, §11.2, §14) | ⬜ |
| 12 | Web app | `/app` sign-in + unlock, calendar, entries, tasks, Tiptap editor, live sync, delete account (§11.3) | ⬜ |
| 13 | Motion polish | Hitch audit with Instruments, 120 fps pass, Reduce Motion pass, web motion (§3.6, §15.1) | ⬜ |
| 14 | Release | Privacy manifest, App Store checklist, accessibility audit, review account, TestFlight (§12) | ⬜ |

Phases 3–7 follow the owner's playbook order (confirmed 2026-10-26). Phases 1–3 run as **Batch A**.

## Log

### Phase 0 — Setup (2026-10-25)
- Repo created at `github.com/Soul-Archive-Limited/folio`.
- gitleaks pre-commit hook in `.githooks/`, CI secret scan, Dependabot.
- XcodeGen project `ios/project.yml` (iOS 26.0, Swift 6); empty app shows "Folio".
- CI green on first push: secret scan, iOS build + test (macos-26), API & web.

### Phase 1 — Design system, greeting, privacy cover (2026-10-26)
- Tokens from `shared/design-tokens.json` → asset catalog (light/dark/high-contrast); 12 AA-checked category colours.
- Type scale, spacing, radii, spring motion + Reduce Motion fallbacks, haptics vocabulary.
- Components: `FolioGlassModifier` (Reduce Transparency / Increase Contrast fallbacks), `GlassCard`, `Chip`, `GlassIconButton`, `EmptyStateView`, toasts with Undo, `AuraBackground`, `AppMark`.
- DEBUG Design Gallery (`-FolioScreen gallery`).
- Greeting intro (full pool, no-repeat, specials, tap-to-skip, skip on quick resume) and app-switcher privacy cover.

### Phase 2 — Data + crypto core (2026-10-27)
- SwiftData schema v1 (`Category`, `Entry`, `EntryPhoto`, `TaskItem`, `UserSettings`) with sync fields, `#Unique`/`#Index`, migration plan; store in a `NSFileProtectionComplete` directory.
- `DayKey`/`MonthKey` floating days; `DiaryStore` (day queries, cached month markers, category CRUD + un-assign on delete, tombstones, greeting summary).
- Folio Markdown codec + `shared/markdown-fixtures.json`; photo pipeline (all metadata stripped, ≤ 2048 HEIC, 240 px thumb, `@concurrent`).
- `FolioCrypto`: data key, AES-256-GCM records with AAD, recovery key (Crockford base32) + HKDF envelope, X25519 device link; `shared/crypto-vectors.json` from WebCrypto.
- DEBUG sample data (40 entries, 25 tasks, 6 categories, generated photos) and 10k stress generator. Greeting summary uses live data.

### Phase 3 — Tabs + Calendar (2026-10-27)
- Native `TabView` (Calendar · Journal · To-do · Profile), tab-bar minimise on Journal/To-do, floating glass "+" with long-press menu.
- Calendar: endless month paging, every cell state (photo tile + "+N", category dots, task rings, all-done check, today, selected spring, out-of-month, filter fade), Today pill, category filter, long-press day menu.
- Day panel (entry cards, tasks that tick in place and stay), finger-tracking collapse to a swipeable week strip with snapping, Jump sheet (year strip 1900→+10, months with entry dots).
- VoiceOver labels + "Days with entries" rotor; AX-size list layout; 10k-entry performance test.
- Journal, To-do and Profile are placeholders; composers are placeholder sheets (Phases 4–7).

### Phase 4 — Composer + entry detail (2026-10-27)
- Half-sheet composer over the calendar (tap a day to move the entry), date pill back to 1900 with optional time, Save/Cancel with discard confirm.
- iOS 26 rich `TextEditor` limited to SPEC §5.1 via a formatting definition; Aa popover (5 inline + 5 block styles, tick checklist item); saved through `MarkdownCodec`.
- PhotosPicker (no permission), camera with explainer, photo strip (drag to reorder, × to remove), category chips with inline create, 2 s draft autosave + "Continue your draft?".
- Entry detail: zoom from the card, full-res carousel + full-screen pinch, share, change date, duplicate, delete with Undo toast, "Same day in other years".

### Phase 5 — To-do (2026-10-27)
- To-do tab: overdue → dated → undated (drag order), collapsible "Completed · N" (persisted), category filter chips, "All clear." empty state.
- Tick: fill + checkmark draw + strike-through + haptic, 1.2 s pause, then moves; tap again to cancel; 4 s Undo toast; untick in Completed is instant.
- Swipe actions (Done, Delete with confirm for notes, Edit, Date menu), glass quick-add bar recognising today/tomorrow, task composer sheet (also from long-press "+").
- UI test proving only Delete removes a task from the calendar; erase-all bug fixed.

### Phase 6 — Journal + Categories (2026-10-27)
- Journal Timeline (sticky month headers, 16:9 cover cards and text cards, zoom to detail), Photos (3-column masonry), category chips, "Write for a past day".
- Categories manager (reorder, swipe delete with counts, edit sheet with 12-swatch grid, 40 symbols, live chip preview, max 30), linked from Profile.
- Category filters on Calendar, Journal and To-do; tests for month grouping, caching, filters, masonry balance, reorder and edit validation.
