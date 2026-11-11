# Folio — security audit (Batch L, 6 November 2026)

Each item: **check performed → command / output → result → fix**. Production = `https://folio.devilsense.com` (API version e3efea83 after the fixes below). Local = `wrangler dev` with the sample diary synced from the Simulator. Tools: gitleaks 8.30.1, npm audit, vitest (API), `strings`/`otool` on an unsigned Release build, curl, Playwright + Brave.

## 1. Secrets

| Check | Command / output | Result | Fix |
|---|---|---|---|
| Whole git history | `gitleaks detect --source . --log-opts=--all --redact` → `119 commits scanned … no leaks found` | Pass | — |
| Built web bundle | `gitleaks dir web/dist --redact` → `scanned ~3.71 MB … no leaks found` | Pass | — |
| App binaries (Release, app + widget + share extension) | `xcodebuild … -configuration Release CODE_SIGNING_ALLOWED=NO`; `strings -a` of each Mach-O → `gitleaks dir` → `no leaks found`; `gitleaks dir Folio.app` → `no leaks found` | Pass | — |
| URLs compiled into the app | `grep -o https?://…` over the strings: only `folio.devilsense.com` (site, `/api/`, `/privacy`, `/terms`, `/download`) and the GitHub repo | Pass | — |
| Server secrets | Only in Cloudflare's secret store (`wrangler secret put`); `api/.dev.vars` holds throwaway local values and is git-ignored; pre-commit gitleaks hook ran on every Batch L commit (`no leaks found`) | Pass | — |

## 2. Tracking, analytics, session replay, ads

| Check | Command / output | Result | Fix |
|---|---|---|---|
| iOS frameworks | `otool -L Folio.app/Folio` → Apple system frameworks and Swift runtime only; `ls Folio.app/Frameworks` → none embedded | Pass | — |
| iOS SDK names | Searched the app's strings for 25 SDK markers (Firebase, Crashlytics, Amplitude, Mixpanel, Segment, Sentry, AppsFlyer, Adjust, Branch, Facebook, analytics, Hotjar, FullStory, LogRocket, PostHog, Bugsnag, Datadog, New Relic, Instabug, Smartlook, UXCam, OneSignal, AdMob, AppLovin…) → one hit, `amplitude` = the dictation waveform's audio level variable | Pass (false positive) | — |
| Web bundles | Searched `web/dist` for 20 tracker markers → `gtag` (inside `Symbol.toStringTag`) and `doubleclick` (`onDoubleClick` event names) only | Pass (false positives) | — |
| Live network | Playwright on the live site: pages request **folio.devilsense.com only**; `/app` email step adds **challenges.cloudflare.com** (Turnstile) only; no cookies or storage on the website | Pass | — |
| Privacy manifest | `PrivacyInfo.xcprivacy`: `NSPrivacyTracking` false, no tracking domains (app + both extensions) | Pass | — |

## 3. Authentication

| Check | Evidence | Result | Fix |
|---|---|---|---|
| Session cookie flags | `api/src/lib/session.ts`: `__Host-` prefix, `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, 30-day max-age; only SHA-256 of the 256-bit token stored (`email-auth.test.ts` "stores only a hash") | Pass | — |
| CSRF / Origin | Live: `POST /api/auth/email/start` with `Origin: https://evil.example` → **403**; `sessions.test.ts` "cookie sessions: state changes need the app Origin"; live socket from another origin refused | Pass | — |
| Rate limits | Tests: email start 3/address/15 min with `Retry-After`, 10/IP/hour; verify 20/IP/hour; delete account 3/day; blob uploads; invite tries 10/IP/hour (`email-auth`, `account`, `batch-f`, `invites` tests, 85/85 pass) | Pass | — |
| OTP brute force | 6-digit code, HMAC with a server pepper, 10-minute expiry, **5 attempts then deleted** ("allows 5 attempts, then the code is gone even if the 6th is right"); 20 verifies/IP/hour; identical response for unknown addresses (no enumeration) | Pass | — |
| OAuth state / PKCE | Live `GET /api/auth/google/start?platform=web` → 302 with `state=w.…`, `code_challenge_method=S256`, `nonce`, `prompt=select_account`; state single-use, 10 min, web flows bound to a `__Host-folio_oauth` cookie; iOS needs the app's own verifier for the 60-s hand-off (`oauth.test.ts`) | Pass | — |
| Apple token checks | Identity token JWT verified against Apple's JWKS, audience = bundle ID, nonce = SHA-256 of the raw nonce; forged signature, wrong audience and wrong nonce rejected (`oauth.test.ts`) | Pass | — |
| Invite gating | Production `INVITES_REQUIRED=true`; new accounts need an open, unexpired, unrevoked invite redeemed atomically (`invites.test.ts`, 7 tests) | Pass | — |
| **18+ gate (new)** | New account without `adult: true` → `403 age_required` before any code is spent, nothing created; with it `age_confirmed_at` set (`age.test.ts`, 4 tests) | Pass | Added this batch |
| Account deletion | `account.test.ts` "wipes D1 and R2, logs only a hash, emails a confirmation", "needs DELETE and a recent sign-in", "answers 409 until the wipe finishes"; Apple refresh token revoked via `appleid.apple.com/auth/revoke` in `UserHub.revokeProviderTokens` (code-reviewed; Apple's endpoint can't be exercised from tests) | Pass | — |
| Review / demo account | Production D1 (read-only): `review_users = 0`, `users = 1` → App Review's sign-in creates a fresh, empty account; the code is a Worker secret; switchable off (`REVIEW_ENABLED`). The live sync test uses it and deletes it afterwards (§ live run in the Batch L report) | Pass | — |

## 4. API authorization and input handling

| Check | Evidence | Result | Fix |
|---|---|---|---|
| Unauthenticated access | Live: `GET account/me`, `sync/pull`, `invites`, `keys/recovery`, `blobs/:id`, `account/devices`, `live`, `POST sync/push`, `DELETE account` → all **401** `{"error":"unauthorized"}`; forged session cookie → 401 | Pass | — |
| IDOR (new tests) | `api/test/idor.test.ts` (6): Bob can't see Alice's records in pull; the same record id from Bob lands in Bob's space and Alice's ciphertext is unchanged; Bob's tombstone doesn't delete Alice's record; can't rename or sign out Alice's devices (404) or see them; can't read, approve or cancel Alice's link request; can't read her recovery envelope; tokens map to their own user only. Existing: blobs (`blobs-keys-link.test.ts`), sessions, invites revoke scoped to creator | Pass | Tests added |
| Validation | zod on every body and query; malformed JSON → `400 {"error":"invalid_request"}`; ids must be UUIDs; blob names `uuid.(thumb|display|full)`; path traversal `../../etc/passwd` → 404 | Pass | — |
| Size limits | Live 2 MB body to `email/start` → **413** `too_large`; JSON 64 KB outside sync; push ≤ 1 MB / 200 changes; blobs ≤ 4 MB per rendition; quotas 1 GB / 50,000 records | Pass | — |
| Error messages | Generic codes only; no stack traces, SQL or class names (`idor.test.ts` "errors don't leak internals"); logs carry error classes, never bodies, tokens or emails | Pass | — |
| SQL | All D1 queries parameterised (`?1…`); no string-built SQL with user input | Pass | — |

## 5. End-to-end encryption (server stores only ciphertext)

| Check | Evidence | Result |
|---|---|---|
| D1 records | Local D1 for the synced sample diary: 102 live records (40 entries, 25 photos, 30 tasks, 6 categories, 1 settings). Searched every decoded ciphertext for 12 known plaintext strings ("Market day", "Morning swim", "tomatoes", "Travel", "Sam", JSON keys `title`, `bodyMarkdown`, `dayKey`, "2026-") → **0 hits**; byte entropy 6.31–7.0 bits/byte (base64-decoded AES-GCM; short records lower) | Pass |
| R2 objects | 399 photo blobs: **0** JPEG/HEIC/PNG headers, entropy **7.945–7.99** bits/byte (random) | Pass |
| Metadata | Columns are id, type, version, size, client time, deleted — no titles, dates or categories (`sync.test.ts` "stores only ciphertext and the minimal metadata") | Pass |
| Production | The same check runs on the production review account during the live sync test, then the account is deleted (Batch L report) | See report |

## 6. Headers, CSP, dependencies

| Check | Evidence | Result | Fix |
|---|---|---|---|
| Website and web app | `curl -I` on `/`, `/features`, `/privacy`, `/cookies`, `/app`, `/app/settings/account`: CSP (`default-src 'self'`, hashed inline scripts, `font-src 'self'`, `frame-ancestors 'none'`; `/app` adds Turnstile only), HSTS 2 years + preload, nosniff, `X-Frame-Options: DENY`, Referrer-Policy, Permissions-Policy (camera, mic, geolocation, payment, usb off), COOP same-origin; `/app` `no-store` + `noindex` | Pass | — |
| API responses | Had HSTS, nosniff, DENY, Referrer-Policy, no-store but no CSP | Improved | Added `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'` and `Cross-Origin-Resource-Policy: same-origin`; deployed e3efea83; verified live |
| npm audit | `api`: `found 0 vulnerabilities` (prod and all); `web`: `found 0 vulnerabilities` (prod and all) | Pass | — |
| Dependabot | `.github/dependabot.yml` weekly for `/api` and `/web`; `gh api …/dependabot/alerts` open alerts → **0** | Pass | — |

## 7. /vibesec review of Batch L changes

- **XSS:** no `innerHTML`, `dangerouslySetInnerHTML`, `eval` or `new Function` anywhere in `web/src`; the welcome name, export and print book render through React text and the Markdown → elements renderer (`Prose`). Pass.
- **File input:** photos dropped on a day or the composer go through `createImageBitmap` → canvas → JPEG (three renditions), so SVG/script payloads and EXIF (GPS) never pass through; non-images are filtered. Pass.
- **CSRF/open redirect:** the new `adult` flag is a boolean / `"1"`; OAuth redirects still go only to `/app?error=` or `folio://auth?error=` with a closed set of reasons (now including `age_required`). Pass.
- **Mass assignment:** new fields enter through zod schemas only; `age_confirmed_at` is set server-side, never from the body. Pass.
- **DEBUG tooling:** `SyncProbe` (file-driven edits, timestamps) is `#if DEBUG`; the Release binary contains none of `FolioSyncProbe`, `probe-in.txt`, `FolioAPIBase`, `FolioResetData`. It logs only test records' titles ("SYNC…"). Pass.
- **Client storage:** new localStorage keys hold interface choices only; the diary key stays in memory or the opt-in non-extractable IndexedDB key. Pass.
- **Export/print:** decrypted only in the tab; the zip is handed to the browser's download; the print layer is removed after printing; nothing is uploaded. Pass.

## 8. /vibesec review of Batch N changes (2026-11-11)

Scope: `git diff e9f7d68..HEAD` — places (iPhone + web), Profile and Edit profile, celebrations, the unlock-method memory, the e2e suite and its CI workflow. The API is unchanged.
- **Links:** every new `href`/`openURL` is `maps.apple.com` built with `URL`/`URLComponents` (the place name only as the `q` value), our own pages, or Settings — no user-controlled scheme or host; external links use `noopener noreferrer`. No open redirect.
- **XSS:** place names, addresses and settings search results render through React/SwiftUI text only (no `innerHTML`/`dangerouslySetInnerHTML`); the celebration selector uses `CSS.escape`; synced places are length-limited and validated on both platforms (`Place.validated()`, `cleanPlace`).
- **Uploads:** the web Edit profile photo is decoded by `createImageBitmap` and re-encoded by canvas to a 256 px JPEG (no metadata, no original bytes), then still passes `Avatar`'s base64 + 400 KB guard and the JPEG-only `data:` URL.
- **Location privacy:** when-in-use only, one fix; a photo's GPS is never stored with the image (unit-tested); place text never logged — the one new log line now records only a MapKit error code (fixed in this review).
- **Storage:** new localStorage keys hold only `"recovery"`/`"qr"` and `"on"`/`"off"`, compared to literals, cleared at sign-out, listed on /cookies.
- **CI:** `e2e.yml` has `permissions: contents: read`, `persist-credentials: false`, SHA-pinned actions, no repository secrets; it generates throwaway `.dev.vars` per run and masks the review code. `pull_request` (not `pull_request_target`), so forks get no secrets.
- **Dependencies:** e2e adds `@playwright/test` 1.64.1 and `@axe-core/playwright` 4.14.0 (dev only, ≥ 2 weeks old, `npm audit` 0).
Result: no vulnerabilities found; one hardening change.

## Summary

No secrets anywhere; no trackers or third-party SDKs; auth, CSRF, rate limits, OAuth and deletion behave as specified; every id-taking route is scoped to the session's user (new IDOR tests); the server holds only ciphertext. Fixes this batch: the 18+ gate (Part 6), API CSP + CORP headers, and six IDOR tests. API tests 85/85; npm audit 0/0; gitleaks clean.

## 9. Batch O — final pass before 1.0 (11 Nov 2026)

| Check | Command / evidence | Result |
|---|---|---|
| Changes since §8 | `git diff --stat ed299a3..HEAD -- api web/src` | API: none. Web: copy and two plain-text strings rendered by React (`savedLine`, composer placeholder); no new inputs, endpoints, `innerHTML` or third-party scripts |
| Secrets in git history | `gitleaks git --redact` | 142 commits, no leaks (pre-commit hook clean on every Batch O commit) |
| Secrets / source maps in the built site | grep `web/dist` for key patterns and `*.map` | None |
| Dependencies | `npm audit` in `api`, `web`, `e2e` (prod and all) | 0 vulnerabilities |
| Live headers | `curl -I` on `/`, `/app`, `/api/health` | HSTS preload, CSP (site: hashed scripts; API: `default-src 'none'; frame-ancestors 'none'`), nosniff, `X-Frame-Options: DENY`, Referrer-Policy, COOP / CORP |
| Account deletion | Local API: delete → users, sessions, records, blobs, key envelopes all 0 | ✔ |
| iOS | Email placeholder now verbatim text (it had been auto-linked); no other security-relevant change | ✔ |

No findings.
