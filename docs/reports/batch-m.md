# Batch M report — Apple's age check and Sign in with Apple notifications

_10 November 2026. The two items left before a public App Store launch that only code could close (COMPLIANCE.md risks R3 and R13). No TestFlight build this batch: the owner can't sign in to App Store Connect for now and asked to ship everything together at the end._

```
PHASE M REPORT
Built:
- iPhone, Declared Age Range (SPEC §10.2b, DECISIONS 299): where iOS says the law requires an age
  check (Texas SB 2420 and similar), ticking "I'm 18 or older" asks Apple for the age range
  (gate 18). 18+ → the box ticks; under 18 → it stays unticked with "Folio accounts are for
  adults. You can keep using Folio on this iPhone without an account — your diary stays here.";
  no answer → a try-again line. The line sits right under the box and is spoken by VoiceOver.
  Elsewhere nothing is asked and the box ticks at once, as before. The age range never leaves
  the iPhone. Entitlement com.apple.developer.declared-age-range (via project.yml).
- iPhone, people signed in before this (DECISIONS 300): checked once per account per device at
  launch where required; under 18 → signed out on that device, diary kept as a guest.
- iPhone, robustness: the check is asked only when both of iOS's signals agree (on the iOS 26.5
  Simulator `requiredRegulatoryFeatures` lists every duty while `isEligibleForAgeFeatures` is
  false); iOS has 3 seconds at launch to say whether it's required ("can't tell" = the box
  alone), and Apple's age request gives up after 2 minutes (once in the Simulator it never came
  back, leaving the box disabled). Only error cases that exist on iOS 26 are matched by name (naming iOS 27's
  new ones stopped the app launching on iOS 26).
- API, Sign in with Apple server-to-server notifications (SPEC §10.2c, DECISIONS 301):
  POST /api/auth/apple/notifications verifies Apple's signed JWT (RS256, issuer, App ID or
  Services ID audience) and then:
  · consent-revoked ("Stop using Apple ID") → every session that existed at that moment ends on
    every device; newer sign-ins are untouched, so replays and late deliveries are harmless;
  · account-deleted (the Apple Account is gone) → Apple sign-in removed and sessions end; if Apple
    was the only way in, the Folio account and its encrypted diary are wiped (nobody could ever
    open it again; devices keep their copy as guests);
  · email-enabled / email-disabled → noted in the log by type, nothing stored.
  Logs carry the event type and outcome only — never the Apple ID or an email. 120/IP/hour.
- Parental consent withdrawn (Texas): Apple stops the app launching; Folio holds nothing tied to
  a child, so no App Store Server Notifications endpoint was built (DECISIONS 302, with reasons).
- Docs: SPEC §10.2b/§10.2c, DECISIONS 299–303, COMPLIANCE §5 + R3/R13 + checklist 7/10,
  APPSTORE.md (Age Assurance answer), Privacy Policy (Apple notifications, age check), PHASES,
  HANDOFF.

Files changed: 17 — new: ios/Folio/Services/Account/AgeAssurance.swift,
  ios/FolioTests/Sync/AgeAssuranceTests.swift, ios/FolioUITests/AgeCheckUITests.swift,
  api/src/auth/apple-notifications.ts, api/test/apple-notifications.test.ts; changed:
  SyncSignInButtons.swift, AccountModel+Manage.swift, AppRootView.swift, project.yml,
  api/src/routes/auth.ts, web/src/pages/privacy.astro, docs (SPEC, DECISIONS, COMPLIANCE,
  APPSTORE, PHASES, HANDOFF, this report).

Screenshots / recordings: docs/screenshots/batch-m/01-age-check-minor-light.png,
  01-age-check-minor-dark.png (Profile → sign-in card, Apple says under 18; taken by the UI test).

Tests: API 95/95 (8 new: consent-revoked keeps newer sessions and survives a replay; events as
  a string with millisecond times; account-deleted with email linked unlinks only; account-deleted
  with Apple only wipes and doesn't call revoke; email events store nothing; unknown Apple ID;
  Services ID audience; forged key, wrong audience, wrong issuer, future iat, missing sub, junk
  and a wrong body all refused with nothing changed). iOS 251 unit tests (3 new decision tests)
  pass; UI: AgeCheckUITests 3/3 (under 18, no answer, adult) in light and dark,
  OnboardingUITests passes (it caught the Simulator's mismatched signals and the hang). Web 114 unit + 28 build checks.
  Release build: 0 warnings. Live API smoke: /health 200; junk payload 400; bad body 400.

Security: gitleaks pre-commit clean; no secrets added (the endpoint needs none — Apple's public
  keys). /vibesec on the new endpoint: signature pinned to RS256 with issuer and audience checks;
  an ordinary Apple identity token can't pass (no `events`); no PII in logs; rate-limited; body
  ≤ 8 KB; every branch idempotent and replay-safe; the only destructive branch (wipe) needs an
  Apple-signed account-deleted for an account with no other way in. API deployed 5517f68b.

Deviations from SPEC: none (SPEC updated in the same change).

Manual steps needed from the owner (when you can sign in to Apple again):
1. developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → com.devilsense.folio
   → Sign in with Apple → Configure → Server-to-Server Notification Endpoint:
   https://folio.devilsense.com/api/auth/apple/notifications → Done → Save.
2. On the same App ID, check "Declared Age Range" is ticked (the next archive's automatic
   signing should add it; tick it yourself if the archive stops on provisioning).
3. At the final ship: in the age-rating questionnaire answer "Age Assurance — Yes" for the build
   that includes this batch.

Open questions for the Architect: none.

Known issues:
1. The real Apple age sheet can't be shown in the Simulator (no age range to share); the flow is
   tested with simulated answers. Apple's Sandbox age-assurance testing needs a device — on the
   "Only you can test" list.
2. Until step 1 above is done, Apple sends no notifications, so the endpoint is idle.

Next phase ready: yes
```

## Only you can test (with the next build)

1. On your iPhone (a Sandbox Apple Account set to Texas, per Apple's "Testing Age Assurance in Sandbox"): Profile → tick "I'm 18 or older" → Apple's age sheet → an adult range ticks the box; a teen range shows the message and leaves it unticked.
2. After step 1 of the owner steps: Settings → your name → Sign-In & Security → Sign in with Apple → Folio → Stop using. Your web session should end within a few seconds.
