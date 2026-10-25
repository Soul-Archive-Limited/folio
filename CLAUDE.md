# Folio — instructions for Claude

Read `docs/SPEC.md` before any task. Follow §0 and §13. Use Context7 for any iOS 26+, Cloudflare, Better Auth or OAuth API. Never write secrets to files. Update `docs/PHASES.md` and `docs/DECISIONS.md` each phase. End every phase with the Phase Report (§18).

## Ground rules

- `docs/PHASES.md` is the roadmap. Do not use the GSD skills (`gsd-*`) in this repo.
- Do not search for or install new skills unless the owner asks.
- After adding or removing iOS files, or editing `ios/project.yml`, regenerate the Xcode project: `cd ios && xcodegen generate`. The `.xcodeproj` is git-ignored; never edit it by hand.
- One-time setup on a new clone: `scripts/setup-hooks.sh` (enables the gitleaks pre-commit hook).
- Never bypass the pre-commit hook (`--no-verify`) to get a commit through. If gitleaks flags something, remove the secret.

## Skills by phase

Use these skills automatically at the start of each phase, in addition to Context7 for current API details (SPEC §0.8). Skills give patterns and judgement; Context7 gives the API surface as it is today. When they disagree, Context7 wins — record the call in `docs/DECISIONS.md`.

| Phase | Skills |
|---|---|
| 1 · Design system | `swiftui-liquid-glass`, `apple-design`, `animate`, `emil-design-eng`, `swiftui-pro` |
| 2 · Data + crypto | `swiftdata-pro`, `cryptokit`, `swift-testing`, `write-swift` |
| 3–6 · Screens | `swiftui-pro`, `swiftui-liquid-glass`, `animate`, `ios-accessibility` |
| 7 · Onboarding + tour | `tipkit`, `swiftui-pro`, `animate` |
| 8 · Dictation + AI | `speech-recognition`, `apple-on-device-ai` |
| 9 · Backend | `hono`, `better-auth-best-practices`, `better-auth-security-best-practices`, `cloudflare`, `workers-best-practices`, `wrangler`, `durable-objects`, `turnstile-spin`, `VibeSec-Skill` |
| 10 · iPhone sign-in + sync | `authentication`, `cryptokit`, `background-processing`, `VibeSec-Skill` |
| 11 · Website | `frontend-design`, `web-perf` |
| 12 · Web app | `tiptap`, `frontend-design`, `VibeSec-Skill` |
| 13 · Motion polish | `animate`, `emil-design-eng`, `apple-design`, `mobile-native`, `web-perf` |
| 14 · Release | `app-store-review`, `ios-accessibility`, `VibeSec-Skill` |

Notes:
- **Email (Phase 9):** send sign-in codes with **Resend**, as SPEC §10.1 says, behind the `EmailSender` abstraction. Use `cloudflare-email-service` only later, once the account is on Workers Paid.
- `VibeSec-Skill` is the `/vibesec` review required by SPEC §13.10 at the end of every backend/web phase.
