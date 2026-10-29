# Folio website — story and copy (Batch H)

The site is built from this file. Voice: calm, plain, personal; British spelling; second person; short sentences. Sell nothing Folio doesn't do. No testimonials, ratings, user counts or press logos — a short note from the maker instead.

**One promise:** Your days, kept. — a calendar diary for iPhone and the web, encrypted so only you can read it.

**Primary actions everywhere:** **Get started** → `/app` (the same Apple / Google / email sign-in creates the account) · **Sign in** → `/app`. Store buttons (TestFlight / App Store) render only when `src/config/site.ts` has a link.

---

## Navigation

Logo · Features · How it works · Privacy · About · FAQ — right: **Sign in** · **Get started**.
Mobile: a full-screen glass sheet with the same links, large, plus the two buttons at the bottom.

## Home

### Hero
- Eyebrow: A calendar diary for iPhone and the web
- H1: **Your days, *kept.***
- Lede: Write about today, or any day back to 1900. Your words, photos and tasks land on one calendar — encrypted so only you can read them.
- Buttons: **Get started** · *See how it works* (scrolls to "A day with Folio")
- Small print under buttons: Free. No account needed on iPhone. No ads, no tracking.
- Visual: a 3D phone floating over the drifting aura, showing Folio's real calendar; it tilts toward the cursor and turns as you scroll.

### Problem — "Where did last spring go?"
- Heading: **Your life is kept in six different places.**
- Intro: And none of them is a diary.
- Four scattered cards that drift together on scroll and settle into one calendar:
  1. **The camera roll** — 14,000 photos, and you still can't find the day you moved in.
  2. **Notes and old notebooks** — a line here, a shoebox of paper diaries there.
  3. **To-dos in another app** — finished, ticked, and gone without a trace.
  4. **Apps that nag** — streaks, badges, a red dot because you had a quiet week.
- Resolve line: **Folio puts them on the one thing you already think in: days.**

### A day with Folio (scroll story, pinned phone, the aura moves from dawn to night)
1. **08:10 · Morning** — *A greeting, not a guilt trip.* Open Folio and it says good morning, with what's on today: two tasks, nothing overdue that can't wait. No streak to protect.
2. **15:20 · Afternoon** — *Tasks that stay where they happened.* Tick "Post the letter to Ana" and it stays on today, done. Next year you'll still see the afternoon you finally sent it.
3. **21:40 · Night** — *Say it on the walk home.* Dictate tonight's page while you walk; the words appear as you talk, on your iPhone, and nothing is sent anywhere. Add the photo from lunch. Save — and it becomes a little picture on today's square.

### Features story — "Everything lands on your calendar"
The month grid assembles itself: day tiles fly in from depth, photo tiles flip in, one page lifts off a day and opens into an entry.
- **Your month at a glance.** Days you wrote on show a tiny photo or a coloured dot. Days with tasks get a ring, and a tick once they're all done.
- **Write for any day.** Pick a date back to 1900 and write in a half sheet while the calendar stays in view.
- **Read it back like a book.** The Journal lays your pages out by month, with covers from your photos — or as one wall of every picture you've kept.
- **Your own categories.** Twelve colours, your names. Filter the calendar to just Travel, or just Family.
- **Nothing vanishes by accident.** Deleted pages wait 30 days in Recently Deleted.
- **A light hand with words.** ✦ suggests a title or tidies grammar, on your iPhone, and never changes anything until you say so.
- Link: *See every feature →*

### Made for how you actually live (use cases)
- **The traveller.** Mia flies Lisbon → Singapore on a Tuesday. Her Tuesday page stays on Tuesday — Folio days never shift when the time zone does. Each city becomes a photo on the day she was there.
- **The student.** Theo keeps deadlines as tasks and his evenings as pages. In June he can scroll back and see the term — what was due, and what it was actually like.
- **The new parent.** Priya started on the day her daughter was born. A photo a day, a line when there's time. The first year fits on twelve calendar pages.
- **The paper diaries.** Jo has 22 notebooks from 1987 to 2009. One entry at a time, dated to the day it was written, with a photo of the page — the shoebox becomes a searchable decade.
- **Two friends, two diaries.** Sam and Alex went to Kyoto together. Each wrote their own Folio — same trip, two private versions. Neither can read the other's, and neither can we.

### Privacy — "Private by design, not by promise"
- Heading: **We can't read your diary. That's the point.**
- Body: Before anything leaves your phone, it's locked with a key that only your devices hold. Our server stores scrambled data it has no way to open — so there's nothing for us to read, sell or hand over.
- Three facts: **Encrypted on your device** · **No ads, no tracking** · **Works without an account**
- Visual: a 3D lock closes over a page as you scroll; ciphertext streams out the other side.
- Link: *How encryption works, in plain English →*

### iPhone and the web
- Heading: **On your iPhone. In your browser.**
- Body: Write on the train, read it back on your laptop. Open folio.devilsense.com/app, scan a code with your iPhone, and your diary unlocks — the key goes phone to browser, never through us.
- Note: Dictation and ✦ stay on iPhone, where they run privately.
- Buttons: **Open the web app** · store button when set.

### FAQ preview
Can you read my diary? · Do I need an account? · What if I lose my iPhone? · Can I write for days in the past? · Does dictation send my voice anywhere? — *All questions →*

### A note from the maker (replaces reviews)
> Folio is made by Soul Archive Ltd, a small company in London, for people who want their days kept — privately. There's no feed, no streak and nothing to share. Just your pages, on your calendar, for as long as you want them.

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
