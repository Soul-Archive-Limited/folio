# Batch E report

Batch E = Batch D fixes (Part 1) · Release-warning fix (Step 0) · Phase 9 backend deployed (Part 2) · Phase 10 iPhone sign-in, encryption and sync (Part 3) · TestFlight build (Part 4). Shape per SPEC §18, one section per part.

---

## Part 1 — Batch D fixes (owner's iPhone test of 0.1.0 (1))

**Built:** the ten fixes from the owner's TestFlight notes — mic explainer, Journal past-day, onboarding keyboard, guided tour (own overlay instead of TipKit), photos clipped in cards and the zoom, photo-tile scrim, swipe and long-press actions on entry cards, drafts only for real changes, Share menu (text · text and photos · image card), ember contrast (DECISIONS 150–158).
**Screenshots / recordings:** `docs/screenshots/batch-e/01…10-*.png` (before/after, light and dark where it matters), `rec-tour-auto-advance.mp4`.
**Tests:** unit + UI tests added (draft baseline, tour, share, entry actions, onboarding); all pass.
**Next phase ready:** yes (committed b96e69c).

## Step 0 — Release archive warnings

**Built:** reproduced with `xcodebuild archive` (Release, generic iOS device). The archive itself had 0 warnings; the three in Xcode's Archive were IDE project validation ("Update to recommended settings", because XcodeGen wrote `LastUpgradeCheck = 1430`). Fixed at the source in `project.yml` (Xcode 27.1 marker, C/C++ standards, string catalogs, module verifier). The App Intents "Metadata extraction skipped" line is Apple's tool output, not a counted warning, and goes away when the app adopts App Intents (DECISIONS 173–175).
**Tests:** CI now builds Release for a device and fails on any warning (`scripts/check-warnings.sh`); checked both ways.

## Part 2 — Phase 9 backend, deployed

**Built:** Worker `folio-api` live on `https://folio.devilsense.com/api/*` with D1 `folio-db` and R2 `folio-blobs` (Western Europe), the `UserHub` Durable Object (live socket, account wipe), rate limits and the nightly clean-up. Secrets: two server keys generated straight into wrangler, the Apple key loaded from its file, Resend and Google pasted by the owner, a temporary App Review code (below). Changes the owner asked for: no admin endpoint and no Cloudflare Access (usage in the dashboard); web email sign-in closed until Turnstile (Batch F). Blob uploads raised to 180/hour (60 photos × 3 renditions) after the live test (DECISIONS 176–179, 186).
**Tests:** 53 API tests pass. Live smoke test: health, an email code to the owner's inbox, sign-in, push/pull, a blob round trip, account deletion — D1 and R2 empty afterwards.
**Security:** gitleaks clean on every commit; no secret in any file. /vibesec on `/api` was done in Phase 9 (DECISIONS 172).

## Part 3 — Phase 10: iPhone sign-in, encryption, sync

PHASE 10 REPORT

**Built:**
- Sign in with Apple (native, nonce), Google (`ASWebAuthenticationSession`, no SDK, PKCE-bound hand-off), email code (one-time-code autofill, resend after 30 s). Buttons now in Release builds. Session in the Keychain (this device only).
- Data Key and recovery key in iCloud Keychain; recovery key screen (copy — local-only, expires in 2 min — save to Files, print, confirm the last 4).
- Unlock on a new device: automatically through iCloud Keychain, by QR from another device (the approving device checks the QR's key against the server's and asks for Face ID / passcode), or with the recovery key. Profile → Link a browser or device (camera scanner).
- Sync engine: dirty tracking, push 2 s after the last edit, pull only when the live socket's cursor moved, WebSocket in the foreground only, background refresh while protected data is available, backoff with jitter and `Retry-After`, encrypted thumb/display/full photo blobs, guest → account upload with progress, last-writer-wins, final tombstones, Recently Deleted and purges across devices.
- Profile signed in: account, sync status (Up to date · Syncing… · Offline — will sync later · Error), last synced, Sync now, Devices (sign out one or all others), Recovery key, Link a device, Sign out (keep or remove this iPhone's copy), Delete account (explain → sign in again → type DELETE → keep or erase).

**Files changed:** 111 files in `ios/`, `api/`, `scripts/`, `.github/` this batch. Key: `ios/Folio/Services/Account/*` (API client, Keychain, account model, sign-in, link), `ios/Folio/Services/Sync/*` (engine, pass, blobs, live socket, payloads), `ios/Folio/Services/Store/DiaryStore+Sync.swift`, `ios/Folio/Features/Account/*`, `ios/Folio/Features/Profile/{ProfileSignedInSection,AccountRoutes,DevicesView,LinkDeviceView,DeleteAccountView}.swift`, `ios/FolioCrypto/{KeyEnvelope,SealedRecord,RecordType}.swift`.

**Screenshots / recordings:** `docs/screenshots/batch-e/00-contact-sheet.png` and:
- `p10-00-onboarding-sync.png` — onboarding step 5 with the live sign-in buttons (light)
- `p10-00b-onboarding-sync-dark.png` — the same in dark (Apple button white)
- `p10-01-profile-guest.png` — Profile as a guest: Sync & web access
- `p10-02-email.png` — Continue with email
- `p10-03-email-code.png` — the 6-digit code screen
- `p10-04-recovery-key.png` — the new recovery key
- `p10-05-recovery-confirmed.png` — last 4 typed, Continue enabled
- `p10-06-first-sync-progress.png` — "Encrypting and syncing 40 pages…"
- `p10-07-all-set.png` — first sync done
- `p10-08-profile-signed-in.png` — Profile signed in
- `p10-14-status-up-to-date.png` — status: Up to date, last synced now
- `p10-23-status-offline.png` — status: Offline — will sync later
- `p10-09b-profile-locked.png` — signed in, diary still locked
- `p10-09-unlock-choices.png` — unlock: scan or recovery key
- `p10-10-unlock-qr.png` — the link QR on the new device
- `p10-11-link-scanner.png` — Link a device (Simulator: paste instead of camera)
- `p10-12-link-approve.png` — "Allow iPhone to read your diary?"
- `p10-13-b-unlocked-synced.png` — the linked device synced
- `p10-18-recovery-entry.png` — unlock with the recovery key
- `p10-15-show-recovery-key.png` — Profile → Recovery key
- `p10-16-b-received-live-edit.png` — an entry written on A, on B
- `p10-24-b-conflict-resolved.png` — conflict resolved to the newer edit
- `p10-17-b-recently-deleted.png` — trashed on A, in B's Recently Deleted
- `p10-19-devices.png` — Devices
- `p10-20-delete-explain.png` — Delete account: explanation
- `p10-20b-delete-reauth.png` — Delete account: sign in again
- `p10-21-delete-confirm.png` — Delete account: type DELETE
- `p10-22-after-delete-guest.png` — after deletion: guest, diary kept
- `rec-sync-two-simulators.mp4` (69 KB) — an entry written on A appears on B about two seconds later

Not captured: the "Error" status (needs a server fault; it's covered by unit tests) and the real camera scanner (Simulators have no camera). The recovery key visible in some shots belongs to the test account, which was deleted.

**Tests:**
- Unit: 157 app tests (15 new for sync, payload encoding, sign-in helpers, link payloads, backoff) + 19 crypto tests (2 new for the envelope and blob formats) — all pass. UI: 10 pass, 14 skipped (live and screenshot-only steps, which need the review code).
- **Live, three Simulators, deployed API (DECISIONS 187):** guest diary (40 entries, 25 photos) → new account ✔; recovery-key unlock ✔; QR unlock ✔; edit on A visible on B in ~1–3 s ✔; offline edit synced on reconnect ✔; conflict → newer edit on both ✔; trash and restore across devices ✔; delete account → 0 rows in every D1 table, 0 objects in R2 ✔ (twice).
- Bugs the live test found and that are fixed: a new record's `baseVersion` was left out of the JSON (every push refused); blobs uploaded before records, so a rate limit blocked all sync; account sheets attached inside the List didn't present and would have closed mid-flow; erase-while-signed-in never re-downloaded; the DELETE field lost focus after the code screen; "last synced" went stale.

**Security:** gitleaks clean on every commit. /vibesec on the auth, crypto and sync code (DECISIONS 188): no tokens, addresses or content in logs; Keychain classes as designed; ephemeral HTTPS session, no cookies or cache; QR key checked against the server; owner auth before the recovery key or a link; DEBUG helpers compiled out of Release. Fixed: privacy cover missing on the new account screens; selectable recovery key text; email used as a localization key.

**Deviations from SPEC:**
1. Sign out leaves the Data Key in iCloud Keychain (deleting a synced item would lock the person's other devices); delete account removes it (182).
2. Blob uploads one at a time (SPEC allows two) and 180/hour instead of 60 (three renditions per photo) (186).
3. The device name is the model ("iPhone"); iOS doesn't share the person's device name (181).
4. The temporary `REVIEW_CODE` was set by Claude with the owner's permission for testing; the owner replaces it in Phase 14.

## Part 4 — TestFlight

**Built:** archived and uploaded from this Mac with `scripts/testflight.sh` — **0.1.0 (BUILD)**. No tag pushed; Xcode Cloud untouched.

### Owner's iPhone checklist (one action per line)
1. Install 0.1.0 (BUILD) from TestFlight when it says "Ready to Test".
2. Re-test the Part 1 fixes: dictate (mic explainer), Journal → Past day, the onboarding name field, the tour, a photo in a card and opening it, swipe a card left and right, long-press a card, open and close an entry without changes (no draft prompt), Share → each of the three, and the orange buttons.
3. Profile → Continue with Apple → choose your Apple Account.
4. Save the recovery key (Save → Files), then type its last 4 characters → Continue.
5. Wait for "You're all set" (your diary uploads encrypted).
6. On the Mac, open the Simulator "Folio Sync B", open Folio → Profile → Continue with Apple → sign in with the same Apple Account (Simulator: Settings → sign in to your Apple Account first if it asks).
7. On that Simulator choose "Scan from your other device"; on your iPhone open Profile → Link a browser or device and point the camera at the Simulator's QR → Allow → Face ID.
8. Write a new entry on your iPhone and watch it appear on the Simulator within a few seconds.
9. On your iPhone, Profile → Recovery key → Face ID → check it matches what you saved.
10. Delete an entry on your iPhone; on the Simulator open Profile → Recently Deleted and check it's there; restore it on the iPhone and check it comes back.
11. Profile → Sign out → "Sign out and keep my diary here"; then Continue with Apple again — the diary unlocks by itself (iCloud Keychain).
12. Test delete on a **test** account only: on the Simulator, Profile → Sign out → remove; Continue with email → use a spare address → finish set-up → Profile → Delete account → Continue → sign in again with the code → type DELETE → delete. Tell me and I'll confirm on the server that nothing is left.
13. Tell me anything that looked or felt wrong, with a screenshot if you can.

**Manual steps needed from the owner:** the checklist above; before App Review (Phase 14) replace the review code with `npx wrangler secret put REVIEW_CODE`; move `AuthKey_RVW7TN9U67.p8` from the Desktop to somewhere safe.
**Open questions for the Architect:** none.
**Known issues:**
1. A first upload of a guest diary with many photos takes a while (180 photo files an hour); it continues in the background and shows Syncing….
2. Simulators can't scan QR codes or enter a passcode from UI tests; those two real paths are only tested on the owner's iPhone (checklist 7 and 9).
**Next phase ready:** yes — Batch F (owner's feedback on this build + Phase 12 web app with Turnstile).
