# Onboarding — what the best flows do, and Folio's redesign

Batch I, Part 3. The owner's iPhone test found a paging glitch (swiping back from the name page left the pager stuck between two pages) and asked for a premium onboarding: fewer words, more showing, an interactive moment, light personalisation, sign-in last, then the tour.

**Method and limits.** This is a study of flows I know well from their public onboarding (App Store builds up to mid-2026) — Day One, Structured, Flighty, Stoic, Opal, Apple Journal and Apple's own first-run screens (Fitness, Invites, Freeform). It wasn't a fresh hands-on run of each app in this session, so details may have shifted in newer versions; the patterns are what matter.

## What each one does well

| App | What it does | Why it works |
|---|---|---|
| **Day One** | A few calm screens, then straight into writing; asks what you journal about; offers a daily reminder; sync/sign-in is optional and comes after you've seen the app. | You reach your first entry in under a minute. Personalisation is light and leads somewhere (prompts). The account never blocks the diary. |
| **Structured** | You build your first day during onboarding: pick a wake-up time, drop in a task, watch it appear on the timeline. | **The interactive moment.** You learn the core gesture by doing it, and you start with real data, not an empty screen. |
| **Flighty** | A short, theatrical demo of a live flight; every permission comes with its own clear "why" screen at the moment it matters. | Shows the product's magic in motion instead of describing it. Permission explainers build trust and raise opt-in. |
| **Stoic** | One question per screen (goals, mood, when you reflect), big type, a thin progress bar, a first mood check-in at the end. | Low effort per screen, visible progress, and the answers obviously shape the app. Ends with a first action, not a feature list. |
| **Opal** | Strong progress indicator, bold typography, personal framing ("what you'll get back"), lots of motion between steps. | Momentum: every step feels like a step forward, and back always works. Copy is short and in the second person. |
| **Apple Journal** | One welcome screen with three icon rows, a privacy reassurance in plain words, then the app. Suggestions permission is asked later, in context. | Restraint. Privacy is stated once, clearly. No account, no questions — the app is the onboarding. |
| **Apple first-run (Fitness, Invites, Freeform)** | The HIG "Welcome to …" sheet: a title, three short feature rows with symbols, one Continue. Appearance follows the system. | A familiar, skimmable pattern that respects the person's time and system settings. |

## Patterns worth keeping

1. **Show, don't tell.** Motion and real UI beat paragraphs. Each screen gets one sentence, at most two.
2. **A first action within ~30 seconds** (Structured, Day One, Stoic): the diary should never start empty if the person is willing.
3. **One decision per screen**, with a big, obvious primary button and a quiet way out ("Not now", "Skip").
4. **Visible progress** (Stoic, Opal): a thin segmented bar, so the end is in sight.
5. **Personalisation that changes something you can see** — categories created for what you'll keep, your name and picture in the greeting, the theme applied live.
6. **Permissions only in context** (Flighty, Apple Journal): none during onboarding.
7. **The account last and optional** (Day One, Apple Journal): "Not now" is as easy as signing in.
8. **Every step reversible**: the system back swipe, not a custom pager; nothing typed is lost going back.
9. **Motion with purpose**, and a calm Reduce Motion version (cross-fades).

## Folio's new flow (Batch I)

A `NavigationStack` of steps (system push/pop, so the back swipe is the real interactive iOS gesture and can never stop half-way), a thin segmented progress bar in the top bar, one sentence per screen, the aura behind everything.

| # | Step | What you do | What it changes |
|---|---|---|---|
| 1 | **Your days, kept.** | Watch a month assemble tile by tile; tap **Get started**. | — |
| 2 | **Start with today** | Write one line, or pick today's photo — and watch it fly into today's square on a mini calendar. **Not now** skips. | A real first entry for today (text and/or photo). |
| 3 | **What will you keep here?** | Tap any of Memories · Travel · Tasks · Old diaries · Gratitude · Work. | Matching categories, ready to use; Old diaries and Tasks shape the tour's wording. |
| 4 | **You** | Your name (optional) and a picture: a Folio avatar or the monogram. | Greeting, Profile, Devices. |
| 5 | **Your look** | Light · Dark · Match iPhone, previewed live; Season effect on or off. | Theme and the aura's seasonal layer, at once. |
| 6 | **Keep it in sync?** | Apple · Google · Email · **Not now — keep it on this iPhone**. | Account, recovery key or unlock as before. |
| → | Greeting, then the tour | | |

Rules: no keyboard is ever carried between steps (focus is dropped before every push and when a step disappears, and a swipe back takes the keyboard with the page); no permission prompts (the photo picker runs out of process); Reduce Motion swaps the fly-in and tile assembly for fades; VoiceOver reads each step's heading and the progress ("Step 2 of 6").
