# Folio — Phases

The roadmap. Each phase ends with a Phase Report (SPEC §18) and waits for the owner's go-ahead before the next one starts. Skills to use per phase are in `CLAUDE.md`.

Status key: ✅ done · 🟡 in progress · ⬜ not started

| # | Phase | Scope (SPEC refs) | Status |
|---|---|---|---|
| 0 | Setup | Repo layout, CLAUDE.md, docs, security guardrails (§13.4–13.6), XcodeGen project, empty app, LICENSE, README, first push | ✅ |
| 1 | Design system | Colour tokens, type scale, spacing, glass helpers, `AuraBackground`, motion + haptics tokens, placeholder icon, launch screen (§3, §4.1) | ⬜ |
| 2 | Data + crypto | SwiftData models, `dayKey`, sync metadata, `PreviewData`, `MarkdownCodec` + shared fixtures, `FolioCrypto` + shared vectors, recovery key encoding (§5, §10.3, §10.4) | ⬜ |
| 3 | Calendar | Tab shell, floating "+", Calendar tab, month paging, cell states, day panel, collapse-to-week, Jump sheet (§2, §6.2, §6.3) | ⬜ |
| 4 | Writing | Composer half sheet, rich text, photos, drafts, entry detail with zoom (§5.1, §6.4, §6.5) | ⬜ |
| 5 | Journal + To-do | Journal tab, To-do tab, task composer, complete/undo flow (§6.6–6.8) | ⬜ |
| 6 | Profile + greeting | Profile tab (guest mode), categories manager, greeting intro, privacy cover, toasts, iPad split view (§4.2, §4.3, §6.9, §6.10, §6.14, §6.16) | ⬜ |
| 7 | Onboarding + tour | Welcome pages, name, sync choice UI, recovery key + unlock screens, TipKit tour (§6.1, §6.13, §6.15) | ⬜ |
| 8 | Dictation + AI | SpeechAnalyzer dictation overlay, Foundation Models ✦ menu, permission explainers (§6.11, §6.12, §7, §8, §9) | ⬜ |
| 9 | Backend | Worker, D1 schema, R2, `UserHub`, Better Auth (Apple/Google/email OTP via Resend), sync, blobs, linking, delete account, rate limits, admin usage (§10, §13, §15.2) | ⬜ |
| 10 | iPhone sign-in + sync | Sign-in flows, Keychain, DK + recovery key, sync engine, live socket, background refresh, QR device linking, delete account in-app (§10.2–10.6) | ⬜ |
| 11 | Website | Astro marketing site, legal pages, support/FAQ, headers, SEO (§11.1, §11.2, §14) | ⬜ |
| 12 | Web app | `/app` sign-in + unlock, calendar, entries, tasks, Tiptap editor, live sync, delete account (§11.3) | ⬜ |
| 13 | Motion polish | Hitch audit with Instruments, 120 fps pass, Reduce Motion pass, web motion (§3.6, §15.1) | ⬜ |
| 14 | Release | Privacy manifest, App Store checklist, accessibility audit, review account, TestFlight (§12) | ⬜ |

Phases 3–6 split the iOS screens into four chunks. The order follows the user's path through the app and can be changed on request.

## Log

### Phase 0 — Setup (2026-10-25)
- Repo created at `github.com/Soul-Archive-Limited/folio`.
- gitleaks pre-commit hook in `.githooks/`, CI secret scan, Dependabot.
- XcodeGen project `ios/project.yml` (iOS 26.0, Swift 6); empty app shows "Folio".
