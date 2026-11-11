# Independent review — raw findings (Batch O)

Written by a separate review agent that had not seen the code: only SPEC.md, the screenshots and the running app (iPhone 17 Pro Simulator, DEBUG build of 11 Nov 2026). It could not write this file itself, so its table is copied here verbatim in substance. Triage and status of every item: `docs/reports/full-audit.md`.

Counts: Critical 0 · High 3 · Medium 9 · Low 10 · Cosmetic 5.

| id | sev | screen | finding | shot |
|---|---|---|---|---|
| F01 | High | Onboarding → Start with today | Tapping the field moves the whole step up: headline under the Dynamic Island, over Back and the progress bar; "Add to today" hidden; Return only closes the keyboard | r01 |
| F02 | High | Guided tour | Taps pass through the card; Next on step 2 opened today's entry; one Next on step 4 jumped to 6 of 6 and opened Profile → Your data | r05, r06, r08 |
| F03 | High | Calendar at AX5, dark | Selected/today row light lilac (#949FFF) under white text (~2:1); list opens scrolled past the month header | r16 |
| F04 | Med | Onboarding → sync | Headline and subtitle truncated at default size (already known) | r03 |
| F05 | Med | Calendar header | Month title truncates when the Today pill appears (already known) | r09 |
| F06 | Med | Guided tour | A 6-step card rather than TipKit tips; translucent card lets text collide; step 2's card covers the grid it asks you to tap | r04, r07 |
| F07 | Med | Task composer | Saved title "Book dentist book dentist" while the field showed one copy (fast synthetic typing) | r10 |
| F08 | Med | Profile at AX5 | Card words split letter by letter; stat labels clipped | r18 |
| F09 | Med | To-do at AX5 | Titles truncate instead of wrapping; notes clipped | r17 |
| F10 | Med | Composer at AX5 | Tool icons overlap; date pill and Save don't scale while chips grow | r19 |
| F11 | Med | Email sign-in | Placeholder "you@example.com" in link blue, looks prefilled | r24 |
| F12 | Low | Onboarding → uses | Only primary button says "Skip"; selected chips have no check mark | — |
| F13 | Low | Day panel | Card shows bold "Untitled" over the line; detail shows no title | r04 |
| F14 | Low | Quick add | "next friday" on Wed 11 Nov → Fri 13 Nov (British usage often the 20th) | — |
| F15 | Low | Sync / Account & Sync | No hint to tick the 18+ box; disabled states inconsistent | r03, r23 |
| F16 | Low | To-do | Search above the title; grey group bands | r17 |
| F17 | Low | Profile → Your data | Title shown twice; scope of "Include Recently Deleted" unclear | r08 |
| F18 | Low | Composer | Typed "- [ ]" not converted to a checklist; body runs under the toolbar at the medium detent | r11 |
| F19 | Low | Composer, future day | "What happened today?" and "Kept on …" for a future day | r11 |
| F20 | Low | Docs | Google scopes differ between SPEC §10.2 and §12 / APPSTORE | — |
| F21 | Low | Docs | APPSTORE "final name/icon" stale; age-rating wording contradicts itself | — |
| F22 | Cos | Onboarding → look | Theme previews use the retired orange accent | r02 |
| F23 | Cos | Calendar header | Header jumps ~5 pt when Today appears | r09 |
| F24 | Cos | Onboarding → first line | Check mark is system blue; mini calendar has no weekday row | — |
| F25 | Cos | Mood / Year in Pixels | Good and Bright read coral rather than amber | r19, r14 |
| F26 | Cos | Save toast | Translucent toast shows the row behind it | r11 |
| F27 | Low | DEBUG argument | `-FolioOpen recentlyDeleted` ignored (needs `-FolioTab profile`) | r22 |

Worked: photo place offer, place chip and line, mood, bloom + "Kept on" toast, Journal (timeline, photos, Year in Pixels, Places), quick-add dates, dark mode at default size.

Not reached (time): accounts on the local API, the web app, Recently Deleted, search, Edit profile, share, change date, current location, place search, To-do extras, celebrations, Face ID, rotation, age-check variants, remaining Profile pages — all covered by the main audit instead.
