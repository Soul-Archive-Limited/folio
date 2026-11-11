# Folio website — story and copy (Batch H)

The site is built from this file. Voice: calm, plain, personal; British spelling; second person; short sentences. Sell nothing Folio doesn't do. No testimonials, ratings, user counts or press logos — a short note from the maker instead.

**One promise:** Your days, kept. — a calendar diary for iPhone and the web, encrypted so only you can read it.

**Primary actions everywhere:** **Get started** → `/app` (the same Apple / Google / email sign-in creates the account) · **Sign in** → `/app`. Store buttons (TestFlight / App Store) render only when `src/config/site.ts` has a link.

---

## Navigation

Logo · Features · How it works · Privacy · About · FAQ — right: **Sign in** · **Get started**.
Mobile: a full-screen glass sheet with the same links, large, plus the two buttons at the bottom.

## Home

### Hero (Batch L)
- Visual: the page is a diary page — faint ruling and an Ink margin line — with the season drifting at the top (same seasons and regions as the app). On the right, the real web app window (calendar) with the 3D iPhone in front.
- Pill: **New in 1.0: places on your pages →** (links to the changelog; change the words with each release, always something true).
- H1: **Your days, *kept.*** — an ink stroke draws once under "kept."
- Lede: A calendar diary for iPhone and the web. Write about today or any day back to 1900 — words, photos and tasks on one calendar, encrypted so only you can read them.
- Buttons: **Get started** · store button when set. Small print: Free · no account needed on iPhone · no ads, no tracking

### The calendar is the diary — "A month you can read *at a glance.*" (Batch L)
- Body: Pages, photos and tasks all belong to a day, so the month itself tells you where you went and what you did. Here is how to read it.
- The real calendar screenshot beside a key drawn like the app's cells: a photo day · dots per category · open tasks · all done · today.
- Six features with Folio's own icons: Write for any day · Read it back like a book · Your own categories · How it felt (mood: five quiet steps, never a face) · Nothing vanishes by accident · A light hand with words. Link: *Every feature, with screenshots →*

### A day with Folio (unchanged; the sky now warms through paper and lilac, not orange)

### The app itself — "Every screen, *as it is.*" (Batch L, replaces the illustrative personas)
- Body: No mock-ups. These are screenshots of the current build, filled with the sample diary we test with.
- A sideways strip: Journal · Year in Pixels · To-do · A page · Search · On this day · Lock Folio · Widgets — each with one line.

### Privacy — "Private by design, not by promise"
- Heading: **We can't read your diary. That's the point.**
- Body: Before anything leaves your phone, it's locked with a key that only your devices hold. Our server stores scrambled data it has no way to open — so there's nothing for us to read, sell or hand over.
- Three facts: **Encrypted on your device** · **No ads, no tracking** · **Works without an account**
- Visual: a 3D lock closes over a page as you scroll; ciphertext streams out the other side.
- Link: *How encryption works, in plain English →*

### Make it yours — "Quiet, *but personal.*" (Batch L)
- The 24 Folio avatars. A picture (24 avatars or a photo) · Your look (light, dark or match; New York or SF Pro) · The season (spring blossom · summer motes · monsoon rain · autumn leaves · winter snow, by where you live, or off) · Colours (twelve swatches).

### iPhone and the web
- Heading: **On your iPhone. In your browser.**
- Body: Write on the train, read it back on your laptop. Open folio.devilsense.com/app, scan a code with your iPhone, and your diary unlocks — the key goes phone to browser, never through us.
- Note: Dictation and ✦ stay on iPhone, where they run privately.
- Buttons: **Open the web app** · store button when set.

### FAQ preview
Can you read my diary? · Do I need an account? · What if I lose my iPhone? · Can I write for days in the past? · Does dictation send my voice anywhere? — *All questions →*

### A note from the maker (replaces reviews)
> Folio is made by Soul Archive Ltd, an independent company registered in England and Wales, for people who want their days kept — privately. There's no feed, no streak and nothing to share. Just your pages, on your calendar, for as long as you want them.

### Closing call to action
- **Start with today.** Get started — it takes a minute. Or open Folio on your iPhone and skip the account entirely.
- Buttons: **Get started** · **Sign in**

### Footer
Product: Features · How it works · Privacy & security · Download · Changelog. Company: About · Support · FAQ · Open source · GitHub. Legal: Privacy policy · Terms · Delete account.
Company line (unchanged): Soul Archive Ltd · Registered in England and Wales · Company no. 16186654 · Registered office: 71-75 Shelton Street, Covent Garden, London, WC2H 9JQ. © 2026 Soul Archive Ltd.

---

## Features (`/features`)
- H1: **Everything Folio does.** Lede: Short list, on purpose. Every screen below is the real app.
- Groups (by use case), each feature with a real screenshot:
  - **Keep your days** — Calendar (photo tiles, dots, rings) · Day panel · Week strip (collapse the month) · Jump to any year.
  - **Write** — Half-sheet composer · Any day back to 1900 · Up to 10 photos per page · Categories · Dictation (on device) · ✦ titles, grammar, find tasks (on device, iPhone 15 Pro and later with Apple Intelligence).
  - **Get things done** — To-do with dates and categories · Ticked tasks stay on their day · Undo.
  - **Read it back** — Journal timeline · Photo wall · Entry detail.
  - **Stay in control** — Recently Deleted (30 days) · Export everything (JSON + photos) · Light and dark · Profile, categories, devices.
  - **Everywhere** — iPhone, iPad, web.

## How it works (`/how-it-works`)
- H1: **Three steps. Then it just keeps your days.**
1. **Write.** Open the half sheet, type or talk, add photos. Pick any date.
2. **It lands on your calendar.** The day fills with your photo or a colour. Tasks ring the day, then tick it.
3. **It syncs, encrypted — if you want it to.** Turn on sync and every page is locked on your phone before upload; your iPhone and browser unlock it, nobody else.
- Footnote: Without an account, step 3 doesn't happen at all — your diary stays on your iPhone.

## Privacy & security (`/security`)
- H1: **Private, explained plainly.**
- Animated diagram: phone (your words, readable) → lock (your key, on your devices) → server (sees only scrambled text) → your other device (unlocks with the same key).
- Sections: What we can see (email, device names, sign-in times, how much encrypted data you store) · What we can't (entries, photos, tasks, categories, titles, dates of your entries, your settings) · Your key (made on your iPhone; iCloud Keychain carries it to your other Apple devices; the recovery key is your backup — we can't reset it) · The web (QR unlock, key travels phone → browser, encrypted end to end) · No tracking (no analytics, no ads, no third-party code; the site sets no cookies; the web app sets one sign-in cookie) · Open source (check it yourself).
- Links: Privacy policy · Source code.

## About (`/about`)
- H1: **Why Folio exists.**
- Diaries used to be private by default — a book in a drawer. Apps made them convenient, then made them into products: streaks to chase, feeds to fill, servers that can read every word. Folio goes back to the drawer, with the convenience kept: a calendar you already understand, photos where they belong, and encryption so the drawer has a lock only you hold.
- What we won't do: show ads, sell or analyse your writing, add streaks, or make a feed.
- Who: Soul Archive Ltd, London. Company details. Contact.

## FAQ (`/faq`) — every question from `src/data/faq.ts`, grouped: Privacy · Using Folio · Your data · Web and devices.

## Download (`/download`)
- H1: **Get Folio.** iPhone (TestFlight / App Store button — shown only when set; otherwise "Coming to the App Store soon"), web (**Open the web app**), requirements (iOS 26 or later; any modern browser).

## 404
- **This page isn't in the diary.** Back to the calendar →

### Batch J additions (Features, FAQ, Download, Changelog)
- **Features** gains three groups before "Get things done": *Find and remember* (Search everything, on your iPhone · On this day · Year in Pixels), *Bring it in* (Scan paper diaries — and share in from any app), *Around your iPhone* (Widgets you can tick · Lock Folio). "Your archive and your data" mentions the typeset PDF.
- **FAQ** adds: Can I search my diary? · Can I lock Folio with Face ID? · Are there widgets? · Can I bring in my old paper diary? · How do I get an account? (invite-only for now; Folio works fully without one) · Can I install the web app on my phone? Export now mentions PDF.
- **Download** adds "Install on your phone" (Safari: Share → Add to Home Screen; Android: ⋮ → Install app; desktop: the install icon).
- Words stay in the house voice: plain, short, no superlatives; "on your iPhone" wherever something stays local.
