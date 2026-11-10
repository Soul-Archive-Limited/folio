# Folio — privacy, legal and consumer compliance (Batch L)

_Prepared 6 November 2026 by the builder for Soul Archive Ltd. This is an engineering review of what the code does against current law and platform rules, with sources. It is **not legal advice**; the owner checklist at the end lists what a person or a lawyer must decide or do._

## 1. Scope and facts

- **Who:** Soul Archive Ltd, private limited company, England and Wales, no. 16186654; registered office 71-75 Shelton Street, Covent Garden, London WC2H 9JQ. Controller for Folio.
- **Distribution today:** iPhone app through TestFlight (external group "Friends", public link), invite-only accounts (`INVITES_REQUIRED=true`); website and web app at folio.devilsense.com (worldwide). No App Store listing yet.
- **What is processed** (from the D1 schema in `api/migrations/0001–0004`, checked line by line): account email; provider account IDs; encrypted Apple refresh token (revocation only); account creation time and, from Batch L, age-confirmation time; per session: device model + OS, platform, created/last seen, token **hash**, device label **encrypted**; diary records and photos **end-to-end encrypted** with metadata (id, type, version, size, client time, deleted); recovery-key envelope; short-lived sign-in state (≤ 10 min); rate-limit counters keyed by an **HMAC of the IP** (≤ 2 days); invites (HMAC + last 2 chars); deletion log (hashed id + time). Nothing else: no analytics, no logs of bodies or ciphertext, no IP addresses at rest. **Operational logs** (Batch L review): Cloudflare Workers Logs keep only the structured events our code writes (event and error-class names, status codes — no IPs, emails, tokens or bodies); request-level invocation logs and traces are **off** (`api/wrangler.jsonc`), so URLs and request metadata are not stored by us.
- **Third parties:** Cloudflare (hosting, D1, R2, Workers, Durable Objects, Turnstile), Resend (sign-in and deletion emails), Apple and Google (independent controllers for their sign-in; Apple for distribution). Measured on the live site (Batch L): marketing pages make requests to folio.devilsense.com only, set **no cookies and no local/session storage**; the web app's email step adds challenges.cloudflare.com (Turnstile) and nothing else; no cookies were set by Turnstile in that test (Brave, which restricts third-party cookies — see §5).

## 2. UK GDPR / Data Protection Act 2018 and EU GDPR

| Requirement | Where Folio stands | Evidence |
|---|---|---|
| Transparency (Arts 12–14) | Privacy Policy rewritten in plain English to match the schema: every stored item with purpose and retention, lawful bases, processors and transfers, rights, complaints. "Last updated" date. | `web/src/pages/privacy.astro` |
| Lawful basis | Contract (account + sync), legitimate interests (security: rate limits, Turnstile, deletion log), legal obligation. No consent-based processing, no marketing. | Privacy Policy "Our lawful bases" |
| Data minimisation (Art 5(1)(c)) | Reviewed in §6: nothing removable without losing a feature the user asked for. IPs only as keyed hashes; diary end-to-end encrypted. | §6 |
| Storage limitation | Sessions 30 days sliding; codes/states valid ≤ 10 min and deleted when used or at the nightly clean-up; abuse counters ≤ 3 days (keyed hashes for IPs and emails, account ids for per-account limits); account data until deletion; D1 Time Travel backups ≤ 30 days (7 on the free plan). | `api/src/index.ts` cron cleanup; policy |
| Security (Art 32) | E2E AES-256-GCM, hashed tokens/codes, HSTS, strict CSP, rate limits. Audited in `docs/SECURITY_AUDIT.md`. | SECURITY_AUDIT.md |
| Rights (Arts 15–22) | Export (iPhone and web, decrypted on device), deletion in app and web (Apple token revoked, R2/D1 wiped, confirmation email), email route for the rest. | §10.6 SPEC; `api/src/hub/UserHub.ts` |
| International transfers (Ch. V) | Cloudflare: EU–US Data Privacy Framework + UK extension, SCCs (2021/914) + UK Addendum as fallback in its DPA. Resend (Plus Five Five, Inc.): DPA with EU SCCs and UK SCCs (EU SCCs + UK Addendum). | [Cloudflare DPA](https://www.cloudflare.com/dpa/), [Resend DPA](https://resend.com/legal/dpa) |
| ICO data protection fee | A UK controller processing personal data electronically must pay unless exempt; Tier 1 (micro) is **£52** (£47 by direct debit) since 17 Feb 2025. The exemptions don't obviously cover running a consumer app with accounts. **Owner action.** | [Lewis Silkin on the 2025 fee rise](https://www.lewissilkin.com/insights/2025/02/06/fee-payable-to-the-ico-to-increase-in-february-102jzb9), [GOV.UK response](https://www.gov.uk/government/consultations/data-protection-fee-regime-proposed-changes/outcome/data-protection-fee-regime-government-response) |
| EU representative (Art 27) | A UK company offering a service to people in the EU with no EU establishment generally needs an **EU representative**; the "occasional processing" exemption is narrow and doesn't fit an app used continuously. Folio's website and web app are reachable from the EU today. **Owner/lawyer decision** (appoint one, or restrict EU sign-ups). | [UK GDPR Art 27 text](https://www.legislation.gov.uk/eur/2016/679/article/27/data.html), [Fieldfisher commentary](https://ukgdpr.fieldfisher.com/chapter-4/article-27-gdpr/) |
| DPIA | Not high-risk processing by the server (it can't read diary content); a short DPIA note is still good practice for a diary product. **Lawyer review.** | — |

## 3. ePrivacy / PECR (cookies and similar storage)

**Decision: no consent banner.** Everything Folio stores in a browser is strictly necessary for a service the person asked for (PECR reg. 6(4) / ePrivacy Art 5(3) exemption):
- `__Host-folio_session` (sign-in) and `__Host-folio_oauth` (10-minute OAuth binding) — needed to provide the signed-in service;
- IndexedDB `folio/trust` — only when the person ticks "Trust this browser";
- localStorage interface choices the person makes (theme, folds, photo tiles, welcome seen, sign-in hint, device-name marker) — remembering a person's own explicit choices; the UK's Data (Use and Access) Act 2025 also added a PECR exception for storage that adapts a service's appearance or functions to a user's preferences (lawyer to confirm the final wording applies);
- Cache Storage (service worker) — the app's own code only, never diary data.
The website stores nothing at all. No analytics or advertising storage exists, so there is nothing to consent to. The ICO updated its storage-and-access guidance on 29 April 2026; the exemption is judged from the user's side and doesn't cover analytics or advertising — consistent with the above. Every item is listed in `/cookies`.
Sources: [ICO cookie guidance updates — Lewis Silkin, Nov 2025](https://www.lewissilkin.com/insights/2025/11/11/ico-sets-the-record-straight-on-storage-and-access-technologies-102ltyf), [Mondaq on the new exceptions](https://www.mondaq.com/uk/privacy-protection/1794248/new-exceptions-for-non-intrusive-cookies-the-icos-updated-guidance-has-landed), [Cloudflare Turnstile Privacy Addendum](https://www.cloudflare.com/turnstile-privacy-policy/).

## 4. India — Digital Personal Data Protection Act 2023 and DPDP Rules 2025

- The Rules were notified on 13/14 November 2025 (G.S.R. 846(E)); most substantive duties apply after an 18-month phase-in, i.e. from **13 May 2027**; consent-manager provisions at 12 months. Sources: [PIB release](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2190014&reg=3&lang=2), [Legal 500 milestones](https://www.legal500.com/intelligence/india/privacy/dpdp-act-and-rules-2025-the-2026-compliance-milestones-businesses-cant-afford-to-miss), [Wikipedia summary](https://en.wikipedia.org/wiki/Digital_Personal_Data_Protection_Rules,_2025).
- **Notice and consent:** the sign-up box ("I'm 18 or older and agree to the Terms and Privacy Policy", unticked) plus the purpose line under it and the Privacy Policy give an itemised notice; withdrawing = deleting the account (self-serve). The policy names the purposes and the data.
- **Contact person (Rule 9) and grievance redressal:** the policy and `/imprint` publish privacy@devilsense.com as the contact who answers questions and handles grievances, with a one-month reply commitment.
- **Children (s.9, Rule 10):** under DPDP a child is under **18**; processing a child's data needs verifiable parental consent. Folio avoids this by making **accounts 18+** (self-declared at sign-up, enforced server-side for new accounts); guest mode on iPhone sends nothing to us, so it involves no processing of a child's data by Soul Archive Ltd. Sources: [DPDP Rule 10 text](https://dpdpa.com/dpdparules/rule10.html), [India Law on verifiable consent](https://indialaw.in/blog/civil/verifiable-consent-data-processing-dpdp).
- Breach notice to the Board and affected people (72 hours under the Rules) — included in the owner checklist as a process to have ready.

## 5. United States

- **COPPA:** applies to services directed to children under 13 or with actual knowledge of collecting their data. Accounts are 18+; guest mode collects nothing; the app isn't directed to children. Low risk.
- **State app-store age laws ("App Store Accountability Acts"):**
  - **Texas SB 2420:** enjoined in December 2025, then the Fifth Circuit stayed the injunction on 28 May 2026; the Supreme Court declined emergency relief on 6 July 2026. **In force since 4 June 2026** for new Texas Apple Accounts. Apple's developer notices say developers "can request age category data … through the Declared Age Range API", must handle consent revocation (`RESCIND_CONSENT`) and the PermissionKit Significant Change flow, and Apple's Q&A says "in regions where legally required, you need to check the age of the people using your app" — with no exemption for 4+ or 18+ apps. Sources: [Apple, 3 Jun 2026](https://developer.apple.com/news/?id=sg176nne), [Apple, 4 Nov 2025](https://developer.apple.com/news/?id=2ezb6jhj), [Apple, 8 Oct 2025](https://developer.apple.com/news/?id=btkirlj8), [Apple age assurance Q&A](https://developer.apple.com/support/age-assurance), [Morrison Foerster](https://www.mofo.com/resources/insights/251111-texas-targets-app-stores-with-new-accountability-law), [Wiley](https://www.wiley.law/alert-Key-Developments-With-State-App-Store-Accountability-Acts-as-Texas-Act-Takes-Effect).
  - **Utah SB 142 (HB 498):** status unclear across sources (May 2026 vs May 2027; state enforcement removed, private action kept). **Louisiana:** HB 977 moved the date to **1 July 2027**. Sources: [FPF comparison](https://fpf.org/blog/comparing-enacted-app-store-accountability-acts/), [Alston & Bird on Louisiana](https://www.alstonprivacy.com/louisiana-delays-app-store-accountability-effective-date-to-july-2027/), [Loeb & Loeb, June 2026](https://www.loeb.com/en/insights/publications/2026/06/childrens-online-privacy-2026-state-app-store-design-code-and-social-media-laws).
  - **What Folio does (Batch M, DECISIONS 299–302):** where iOS says the check is required, ticking the 18+ box asks Apple for the age range (Declared Age Range, gate 18, entitlement `com.apple.developer.declared-age-range`); under 18 → no account (guest mode stays open and sends nothing); no answer → no account until it works. People signed in before this are checked once per device at launch where required; under 18 → signed out there. Withdrawn parental consent: Apple stops the app launching, and Folio holds nothing tied to a child, so no `RESCIND_CONSENT` endpoint is needed (DECISIONS 302). No significant change declared. Elsewhere the self-declared box is the rule. Ships in the next TestFlight build; the API needs nothing for it.

## 6. Data minimisation review

| Item | Needed for | Kept? |
|---|---|---|
| Email | Sign-in, account linking, deletion confirmation | Yes |
| Apple/Google account ID | Sign-in | Yes |
| Apple refresh token (encrypted) | Apple requires revoking the token on deletion (5.1.1(v)) | Yes |
| Device model + OS, created, last seen | Devices list: see and sign out devices (SPEC §6.9) | Yes |
| Device label | Encrypted; only the person can read it | Yes |
| Age-confirmation time | Shows sign-up met the 18+ rule | Yes (new, one timestamp) |
| IP address | Rate limits only — stored as a keyed hash, ≤ 2 days | Hash only |
| Diary content | Sync | Only end-to-end encrypted |
| Name, avatar, settings | Encrypted inside the settings record | Server can't read them |

Nothing found to remove. The web app's `folio.device` localStorage marker avoids re-sending the browser name; kept.

## 7. Platform rules

- **Apple 5.1.1** (data collection and storage): privacy policy linked in App Store Connect and in the app (Profile → About); account optional (guest mode); account deletion in app and on web with Sign in with Apple token revocation (5.1.1(v)); purpose strings only at use. **4.8 Login Services:** Sign in with Apple offered first, with equal prominence to Google. The system `SignInWithAppleButton` is used on iPhone; the web uses "Continue with Apple" with Apple's logo per Apple's web button rules (black/white, unmodified logo, same size as other options).
- **Age rating:** stays **4+** — Apple's rating reflects content (none mature; diary content is private, not user-generated content shared with others). Restricting *accounts* to adults is a service rule, declared truthfully in the questionnaire's "Age Assurance" item only once the Declared Age Range API is adopted.
- **App Privacy label** (`docs/APPSTORE.md`): Email; Photos or Videos; Other User Content; User ID; Other Data (device model + OS) — all App Functionality, linked, not tracking. Matches the policy and `PrivacyInfo.xcprivacy`. The new age-confirmation timestamp is account metadata, not a new data type.
- **Google OAuth (API Services User Data Policy):** scopes `openid email` only since Batch L (`profile` dropped — name and picture were never used; Apple's web flow likewise asks for email only); homepage, privacy policy and terms URLs on the consent screen; the policy now states Google user data is used only to sign in. Verification of the consent screen (logo/branding) is in the owner checklist.
- **Trademarks:** "Sign in with Apple" / Apple logo only inside sign-in buttons; Google "G" mark unmodified in the white button per Google's branding guidelines; the site says "for iPhone" and "iPhone and the web" descriptively; no Apple product imagery other than our own simple phone frame around our own screenshots; the 3D phone is our own generic geometry. App Intent texts avoid Apple product names (DECISIONS 274).

## 8. Assets and licences

| Asset | Source | Licence |
|---|---|---|
| Instrument Serif (website headings) | Self-hosted WOFF2 from @fontsource | SIL Open Font License 1.1 (`web/public/fonts/InstrumentSerif-OFL.txt`) |
| Body text | System fonts (SF Pro / New York on Apple devices, system UI elsewhere) — not shipped by us | Apple's system fonts, used by the OS |
| Folio mark, app icon, 25 custom icons | Drawn by us (`scripts/brand/`) | © Soul Archive Ltd |
| 24 Folio avatars | Generated by us (`scripts/avatars/generate.py`) | © Soul Archive Ltd |
| Sample photos (screenshots, `web/public/img/photos`) | Rendered by the app's own sample renderer | © Soul Archive Ltd |
| 3D phone and lock | Our own geometry in three.js (MIT) | Code MIT; models ours |
| SF Symbols (iPhone app only) | Apple | Apple's SF Symbols licence: use in apps for Apple platforms — **not** used on the web (the web uses our own icon paths) |
| Apple and Google sign-in marks | Apple / Google | Their brand guidelines, inside sign-in buttons only |
| Open-source dependencies | npm (web, API), Apple frameworks only on iOS | Listed at `/open-source` |

No Google Fonts, CDNs, embeds, external images or scripts anywhere except Turnstile on the web app's email step (CSP enforces `font-src 'self'`, `img-src 'self' data: blob:`, `script-src 'self'` + challenges.cloudflare.com on `/app` only).

## 9. Consumer law

- **Free, no purchases:** `/refunds` says so plainly; no payment details are ever requested.
- **Terms** updated: 18+ accounts, Acceptable Use, ending the service with notice and export time, changes notified in advance, English law with consumers' local protections preserved.
- **EU Digital Services Act trader status:** to declare at App Store public launch (APPSTORE.md). Owner action.
- **Company details** (Companies Act 2006 / Company, LLP and Business Names Regulations 2015 — name, number, registered office on websites): in every footer and at `/imprint`; in the app at Profile → About → Company details.

## 9a. Record of processing (UK GDPR Art 30, short form)

| Processing | Data subjects | Data | Purpose / basis | Recipients | Retention |
|---|---|---|---|---|---|
| Accounts and sign-in | Account holders (18+) | Email, provider ids, encrypted Apple refresh token, created/age-confirmed times | Contract | Cloudflare (processor); Apple/Google (independent controllers for their sign-in); Resend (codes) | Until deletion |
| Sync | Account holders | E2E-encrypted records and photos + sync metadata; device model/OS, last seen | Contract | Cloudflare | Until deletion (tombstone markers until the account is deleted) |
| Security | Visitors who request codes or sign in | Keyed hashes of IP/email; account-id counters; Turnstile signals (Cloudflare) | Legitimate interests | Cloudflare | ≤ 3 days |
| Support | People who email us | Email, message | Legitimate interests | Email provider | ≤ 24 months |

## 10. Risk register

| # | Risk | Likelihood | Impact | Mitigation / status | Owner |
|---|---|---|---|---|---|
| R1 | No EU Art 27 representative while EU residents can sign up | Medium | Medium (regulatory) | Appoint a representative, or restrict EU sign-ups until then | Owner + lawyer |
| R2 | ICO fee unpaid | High if not paid | Low–medium (fixed penalty) | Pay Tier 1 fee and register | Owner |
| R3 | Texas SB 2420 / Utah / Louisiana age-signal duties at public App Store launch | Medium | Low | **Done in Batch M:** Declared Age Range on sign-up and a one-time check for signed-in people where required; consent withdrawal needs no endpoint (§5, DECISIONS 299–302). Remaining: lawyer confirms no significant-change duty for planned updates | Owner (lawyer) |
| R4 | Self-declared 18+ can be false | Medium | Low (no child data needed by the service; E2E) | Server-side gate for new accounts; delete accounts known to be under 18; Declared Age Range later | — |
| R5 | Processor DPAs not formally accepted | Low | Medium | Cloudflare and Resend DPAs are incorporated by their terms; confirm acceptance/records in each dashboard | Owner |
| R6 | Turnstile cookies in browsers other than Brave | Low | Low | Any such cookie is a security cookie (strictly necessary); Cookie Policy says so | — |
| R7 | Legal pages not lawyer-reviewed | Medium | Medium | Final review before public launch | Lawyer |
| R8 | DPDP duties from 13 May 2027 (breach notice process, records) | Low today | Medium | Grievance contact published; write a breach-response note before May 2027 | Owner |
| R9 | Export-control self-classification (US EAR, year-end) | Low | Low | Adviser question (DECISIONS 143) | Owner + adviser |
| R10 | Existing accounts (owner + one friend) predate the 18+ rule and the updated Terms | Low | Low | Tell both in person/email that the Terms changed (6 Nov 2026); their `age_confirmed_at` stays empty | Owner |
| R11 | Turnstile: Cloudflare may act as controller for some bot-detection signals | Low | Low | Lawyer to check the Turnstile Privacy Addendum's role wording; adjust the policy if needed | Lawyer |
| R12 | Resend keeps delivery logs (codes in subject lines) for its plan's retention | Low | Low | Check the plan's log retention; consider putting the code in the body only | Owner |
| R13 | Sign in with Apple server-to-server notifications (consent revoked, account deleted) not handled | Low | Low | **Done in Batch M:** `/api/auth/apple/notifications` ends sessions on consent-revoked and unlinks or wipes on account-deleted (SPEC §10.2c). Remaining: register the URL on the App ID | Owner (portal) |
| R14 | This document is public on GitHub and lists open owner actions | — | Low | Owner decides whether to keep it public | Owner |
| R15 | Email-code takeover by slow guessing | Low | High | Batch L: 20 checks per address per day, 10 codes per address per day, 5 tries per code | — |

## 11. Owner checklist (only a person can do these)

1. **Pay the ICO data protection fee** (Tier 1, £52/year, or £47 by direct debit) and register Soul Archive Ltd: ico.org.uk/for-organisations/data-protection-fee.
2. **Decide on an EU Article 27 representative** (or restricting EU sign-ups) with a lawyer before wider launch.
3. **Cloudflare:** in the dashboard, confirm the DPA applies to the account (Account → Configurations → Legal/Privacy) and keep a copy. **Resend:** confirm the DPA (incorporated in their Terms; signed copy available on their site) and keep a copy.
4. **Lawyer review** of `/privacy`, `/terms`, `/cookies`, `/acceptable-use`, `/refunds` and this document before the public App Store release.
5. **EU DSA trader declaration** in App Store Connect at public launch (APPSTORE.md has the steps).
6. **Google OAuth consent screen:** check app name, logo, homepage, privacy and terms URLs; request branding verification if Google asks.
7. **Apple developer portal (when you can sign in):** on Identifiers → com.devilsense.folio, (a) check **Declared Age Range** is enabled (the next archive's automatic signing should do it; enable it by hand if the archive stops on provisioning), and (b) under Sign in with Apple → Configure, set the **Server-to-Server Notification Endpoint** to `https://folio.devilsense.com/api/auth/apple/notifications`, then Save.
8. Keep a short **breach-response note** (who decides, ICO within 72 hours, users without undue delay; India Board once DPDP duties apply).
9. Tell your one friend (the only other account) that the Terms and Privacy Policy changed on 6 Nov 2026 (18+ accounts, Acceptable Use).
10. In the **App Store age-rating questionnaire**, answer **Age Assurance — Yes** once a build with the Batch M age check is the one being reviewed (see `docs/APPSTORE.md`).
11. Decide whether `docs/COMPLIANCE.md` (with this checklist) should stay public in the open-source repository.
12. Have the lawyer confirm the dated legal facts in §4–§5 (Texas SB 2420 timeline, ICO guidance date, whether the DUAA 2025 PECR preference exception has commenced).
