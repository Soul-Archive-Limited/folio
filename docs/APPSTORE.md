# Folio — App Store notes

What to type into App Store Connect, field by field. Final for the TestFlight external beta (Batch G, Phase 14); re-check the items marked **before public release** when the final name and icon arrive. Sources and reasoning: DECISIONS 143, 209–211. Apple's rules were checked on 2026-10-29.

## Listing

| Field | Value | Limit |
|---|---|---|
| Name | **Folio Diary** (the App Store Connect record; working name — change with the final name) | 30 |
| Subtitle | **Calendar diary, encrypted** | 30 |
| Primary category | Lifestyle | |
| Secondary category | Productivity | |
| Bundle ID | `com.devilsense.folio` | |
| Privacy Policy URL | https://folio.devilsense.com/privacy | |
| Support URL | https://folio.devilsense.com/support | |
| Marketing URL | https://folio.devilsense.com | |
| Account deletion URL (if asked) | https://folio.devilsense.com/delete-account | |
| Copyright | © 2026 Soul Archive Ltd | |
| Seller / developer | Soul Archive Ltd (Organization account) | |
| Price | Free, no in-app purchases | |

**Promotional text** (170 max, can change any time without a new build):

> Your days on a calendar. Write for today or any day in the past, add photos and tasks, and keep it private — encrypted on your iPhone before anything syncs.

**Keywords** (100 max, commas, no spaces; words already in the name and subtitle — Folio, Diary, Calendar, encrypted — are indexed anyway and left out):

```
journal,private,photo,memories,tasks,to-do,daily,writing,notes,offline,dictation,secure,day,planner
```
(99 characters)

**Description** (4,000 max):

> Folio is a private diary built around a calendar.
>
> Open the app and you see your month. Days you wrote on show a tiny photo or a coloured dot; days with tasks show a ring. Tap a day and its pages and tasks appear underneath. Writing opens in the bottom half of the screen, so the calendar stays in view.
>
> WRITE FOR ANY DAY
> Pick any date — yesterday or 1998 — so you can move your old paper diaries in. Add up to ten photos to a page, format your text, give it a category and a colour.
>
> TASKS THAT STAY ON THEIR DAY
> A simple to-do list feeds the same calendar. Tick a task and it stays on its day, shown as done. No streaks. No nagging.
>
> PRIVATE BY DESIGN
> • Use everything without an account. Your diary stays on your iPhone.
> • Turn on sync with Apple, Google or email to use Folio on another iPhone and on the web. Everything is encrypted on your device before it leaves; we can't read it.
> • A recovery key lets you open your diary on a new device. We never see it.
> • No ads. No tracking. No analytics.
>
> ON-DEVICE HELP
> Dictate entries with on-device speech recognition, and — on iPhones with Apple Intelligence — get title ideas, a light grammar polish and tasks found in your writing. It all runs on your iPhone.
>
> ALSO
> • Journal timeline and a photo wall of everything you've written
> • Recently Deleted keeps deleted items for 30 days
> • Export your diary any time (JSON + photos)
> • iPad: calendar and day side by side
> • Light and dark, Dynamic Type, VoiceOver labels, Reduce Motion
> • Open source
>
> Made by Soul Archive Ltd, London.

**Screenshots** (`docs/appstore/`, JPEG, no alpha, sample data):
- iPhone 6.3" (required size 1206 × 2622): `iphone-01-calendar.jpg` … `iphone-07-calendar-dark.jpg` (calendar, composer, entry, Journal, To-do, "Private by design", calendar in dark).
- iPad 13" (2752 × 2064 landscape): `ipad-01-calendar.jpg` … `ipad-04-composer.jpg`.
- Apple accepts these for the other sizes; the 6.9" (1320 × 2868) slot is optional.

## App Privacy (the "nutrition label")

Privacy Policy URL: https://folio.devilsense.com/privacy. Answer **Yes, we collect data**, then exactly these five types. For each: used for **App Functionality** only; **linked to the user: Yes**; **used for tracking: No**.

| Category → type | Why |
|---|---|
| Contact Info → **Email Address** | Signing in (account email; Resend delivers sign-in codes). |
| User Content → **Photos or Videos** | Photos in entries, synced end-to-end encrypted. |
| User Content → **Other User Content** | Entries, tasks and categories, synced end-to-end encrypted. |
| Identifiers → **User ID** | The account id and the Apple/Google account ids that let you sign in. |
| Other Data → **Other Data Types** | Each signed-in device's model and system version, shown in Profile → Devices. |

The diary content is declared even though it reaches the server only end-to-end encrypted and Soul Archive Ltd can't read it: Apple's App Privacy page has no exemption for encrypted data, so we declare it, as Day One and Ente do (owner decision, DECISIONS 212). The privacy policy explains that the label lists it while we still can't read it.

**Not collected:** location, contacts, health, financial info, browsing/search history, usage data, diagnostics, purchases, sensitive info. Network addresses are only counted, as keyed hashes, for up to two days to stop abuse.

`PrivacyInfo.xcprivacy` matches: no tracking, no tracking domains, the same five types, UserDefaults reason `CA92.1`.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` is in the app's Info.plist, so App Store Connect doesn't ask on each build. Folio uses only Apple's operating-system encryption (CryptoKit AES-GCM, HKDF, X25519; HTTPS) — Apple's table: "encryption limited to that within the Apple operating system" → no documentation in App Store Connect. **Before public release:** the US year-end self-classification question stays with your adviser (DECISIONS 143).

## Age rating (iOS 26 questionnaire)

Answer **None / No** to everything:
- In-app controls: Parental Controls — No; Age Assurance — No.
- Capabilities: Unrestricted Web Access — No (links open Safari; the Google sign-in sheet is only for signing in); User-Generated Content — **No** (entries are seen only by the person who wrote them, never shared or published); Social Media — No; Messaging and Chat — No; Advertising — No.
- Mature themes, Medical or Wellness, Sexuality or Nudity, Violence, Chance-Based Activities (gambling, simulated gambling, contests, loot boxes) — None.

Expected result: **4+**.

## EU Digital Services Act

**Not done for TestFlight** — the owner does it for the public App Store launch. Then declare **trader: Soul Archive Ltd** (a company selling to the public is a trader). App Store Connect shows the D-U-N-S address automatically; enter phone and **support@devilsense.com**; both are verified by code. Apple may ask for a document showing the business name and address (e.g. the Companies House certificate for company 16186654), and you certify you only offer products that comply with EU law. This is an account-level step for the Account Holder or Admin.

## App Review information (used by both App Review and TestFlight App Review)

- **Sign-in required:** No — an account is optional.
- **Demo account:** user name `review@devilsense.com`, password field: *the 6 digits you set with* `npx wrangler secret put REVIEW_CODE` (see below).
- **Contact:** your name, phone, support@devilsense.com.
- **Notes** (paste, then put your 6 digits where it says so):

> Folio works fully without an account: on the first screens tap "Not now — keep it on this iPhone" and every feature is available.
>
> To test sync (optional): Profile → Continue with email → enter review@devilsense.com → enter the code ______ (no email is sent for this address). On a new account Folio shows a recovery key: tap Copy or Save, type its last 4 characters, Continue.
>
> Account deletion: Profile → Delete account → confirm with the same email code → type DELETE. This deletes the account and everything stored on our servers, and revokes Sign in with Apple when used.
>
> Diary content is end-to-end encrypted on the device (Apple CryptoKit); our server stores only ciphertext. Linking a web browser uses a QR code scanned from a signed-in iPhone (Profile → Link a browser or device) and needs a second device. Dictation uses on-device speech recognition; the ✦ writing tools appear only on devices with Apple Intelligence turned on.

**After approval:** set `REVIEW_ENABLED` to `"false"` in `api/wrangler.jsonc` and deploy, or keep it on until the app is approved for the App Store as well (it's needed again for that review).

### The review code (you choose the 6 digits)

Run this in Terminal from the project folder, then type six digits when it asks (they never go into a file):

```bash
cd api && npx wrangler secret put REVIEW_CODE
```

## TestFlight — Test Information (external group "Friends")

| Field | Value |
|---|---|
| Beta App Description (required) | Folio is a private calendar diary. Write for any day, add photos and tasks, and keep it on your iPhone or sync it end-to-end encrypted. Please try writing a few pages, adding photos and ticking tasks, and tell us anything that feels wrong. |
| Feedback Email | support@devilsense.com |
| Marketing URL | https://folio.devilsense.com |
| Privacy Policy URL | https://folio.devilsense.com/privacy |
| What to Test (per build) | Writing and editing pages with photos; tasks; the Journal; Recently Deleted; optional sync with Apple/Google/email and the web app at folio.devilsense.com/app. |
| Sign-in / review notes | Same as App Review information above. |

External testing needs TestFlight App Review for the first build only; up to 10,000 external testers; a public link can be "Open to Anyone".

## Accessibility (App Store accessibility labels — optional)

Evidence so far (DECISIONS 211): Dark Interface ✔, Larger Text ✔ (to AX5; the calendar becomes a list), Reduced Motion ✔, Differentiate Without Color Alone ✔ (states also use checkmarks, rings and words), Sufficient Contrast ✔ (AA measured). **Don't declare VoiceOver or Voice Control yet:** every control has a label, but nobody has done the common tasks end to end with VoiceOver on a real iPhone. Leave this section empty for TestFlight.

## Before a public App Store release

1. Final name (rename everywhere; App Store Connect name and subtitle).
2. Final app icon (Icon Composer, light/dark/tinted; the current one is a placeholder).
3. Legal review of the Privacy Policy and Terms (drafts, not legal advice).
4. US encryption year-end self-classification — ask your adviser (DECISIONS 143).
5. VoiceOver walk-through on your iPhone before declaring accessibility labels.
6. A device run of Instruments (Animation Hitches) — the Simulator can't run it (DECISIONS 205).
7. Google OAuth consent screen verified (app name, logo, privacy + terms URLs, `devilsense.com`, scopes `openid email profile`).
8. Decide when to switch `REVIEW_ENABLED` off.
