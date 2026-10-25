# Folio

A private diary built around a calendar, for iPhone and the web. Write for any day, keep tasks on the same calendar, and sync across devices with end-to-end encryption, or use it with no account at all.

> **Status:** early development. See [`docs/PHASES.md`](docs/PHASES.md) for the roadmap.
> Folio is a working name.

## What's in this repo

| Folder | What it is |
|---|---|
| `ios/` | Native iPhone/iPad app: Swift 6, SwiftUI, iOS 26+. The Xcode project is generated with XcodeGen. |
| `api/` | Cloudflare Worker backend (Hono, D1, R2, Durable Objects). Starts in Phase 9. |
| `web/` | Marketing site and web app (Astro + React) on Cloudflare Pages. Starts in Phase 11. |
| `shared/` | Test vectors shared by iOS and web: Markdown codec and crypto. |
| `docs/` | [`SPEC.md`](docs/SPEC.md) (the source of truth), [`PHASES.md`](docs/PHASES.md), [`DECISIONS.md`](docs/DECISIONS.md), [`APPSTORE.md`](docs/APPSTORE.md). |

## Privacy

Diary content is encrypted on your device before it syncs. The server only stores ciphertext, so Soul Archive Ltd cannot read anyone's diary. The iOS app has no analytics, no ads, no tracking and no third-party SDKs. Details: SPEC §10.3 and §13.

## Getting started

Requirements: macOS with Xcode 26 or later, [Homebrew](https://brew.sh).

```bash
brew install xcodegen gitleaks
```

```bash
scripts/setup-hooks.sh
```

```bash
cd ios && xcodegen generate && open Folio.xcodeproj
```

Pick an iPhone simulator and press Run. The Simulator needs no signing.

The `.xcodeproj` is generated and git-ignored. After adding files or editing `ios/project.yml`, run `xcodegen generate` again.

### Signing (real devices only)

To run on a physical iPhone, or once the app uses Sign in with Apple or iCloud Keychain, set your Apple Developer Team ID in `ios/project.yml`:

```yaml
DEVELOPMENT_TEAM: "ABCDE12345"
```

Then run `xcodegen generate` again. Don't set the team in Xcode's Signing & Capabilities tab: Xcode writes it into the generated project, and the next `xcodegen generate` erases it.

## Security

- Secrets never go in this repo. Server secrets live only in Cloudflare's secret store (`wrangler secret put`).
- A gitleaks pre-commit hook blocks commits that contain secrets, and CI scans every push.
- To report a vulnerability, email **support@devilsense.com** rather than opening a public issue.

## Licence

Code: [Apache License 2.0](LICENSE). The names "Folio" and "Soul Archive" and the app icon are not covered by the code licence (see [`NOTICE`](NOTICE)).

© 2026 Soul Archive Ltd · Registered in England and Wales · Company no. 16186654
