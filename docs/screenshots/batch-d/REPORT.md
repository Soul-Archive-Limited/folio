# Batch D report (SPEC §18) — 2026-10-27

Batch D = Batch C fixes · Recently Deleted · Phase 11 website · automatic TestFlight builds with Xcode Cloud.
Commits: `929d7f2` Batch C fixes · `7fc2628` Recently Deleted · `fe71413` Phase 11 · `efd90a3` Xcode Cloud · report/HANDOFF commit after. Tag `testflight-0.1.0` → first Xcode Cloud build.

## Part 1 — Batch C fixes

**Built**
- Profile "Writing since" = earliest `dayKey` across entries.
- Task composer: turning on Date raises the sheet and scrolls the form to its top edge (`ScrollPosition`), so Title stays visible above the whole picker.
- To-do quick-add vs the minimising tab bar: `.tabViewBottomAccessory` checked (Context7 + SDK) and tried in the Simulator — its text field sits behind the keyboard while typing, and per-tab `isEnabled:` needs iOS 26.1. Instead the bar follows the tab bar's live shape and drops beside the minimised circle (no gap); it rises above the keyboard while typing.
- Task composer category chips moved to a section header (no row panel).

**Tests:** `QuickAddInlineUITests` (drop, taps, focus); Profile stats test updated.

## Part 2 — Recently Deleted (SPEC §5.2)

**Built**
- SPEC §5.2 written; §5 rule, §6.5/6.7/6.8/6.9/6.10, §10.5 and §14.1 updated.
- Schema v3: `trashedAt` on Entry, TaskItem, Category; `Category.unassignedIDs`; frozen v2 models; lightweight migration.
- Every live query skips trash (calendar markers, day panel, Journal + Photos, To-do, Jump dots, Profile stats, greeting summary, same-day-other-years, category counts, export).
- Delete without "Are you sure?" → "Moved to Recently Deleted · Undo". Recently Deleted screen: Entries / Tasks / Categories, original date + days left, preview with Restore / Delete now, swipe Restore / Delete now, Select → Restore selected / Delete selected, Empty with warning haptic, empty state.
- Entry points: Profile → Your data → Recently Deleted · N; quiet links at the end of the Journal timeline and To-do.
- Restore toast "Restored to Mon 26 Oct · Show" (Show jumps to the day; undated task → To-do).
- Category trash records the items it un-assigned; restore re-links them (unless re-categorised since), renames on a clash.
- 30-day purge on launch, foreground and background refresh (only while protected data is available), on a monotonic clock. Erase empties it. Export "Include Recently Deleted" toggle (off by default).

**Tests:** 11 new unit tests (hidden from every view and count, restore day/category/photos, completed task survives, category re-link, re-link after both trashed, name clash, purge at 30 days with injected clock, tombstone purge, clock backwards, Delete now/Empty/Erase, export with and without trash) + v2→v3 migration test + `RecentlyDeletedUITests` end to end.

## Part 3 — Phase 11 website (`/web`)

**Built**
- Astro static + one React/Motion island; paper light + dark from `shared/design-tokens.json`; self-hosted Instrument Serif.
- Hero phone: live recreation of the calendar (composer rises and types, Save drops the photo tile on today, month swipes); pauses off screen; Reduced Motion shows the final frame.
- Pages: Home, Privacy, Terms, Support (FAQ incl. Recently Deleted and "Can you read my diary?"), Open source, Changelog, Delete account, 404; company footer; sitemap, robots, OG image, favicons.
- CTAs from `src/config/site.ts`; buttons render only when set (hero shows "View the source on GitHub" + "How your privacy works").
- No cookies, analytics or forms. `public/_headers` with SPEC §11.3 headers; inline scripts hashed into the CSP at build time.

**Lighthouse** (mobile, local server with gzip + `_headers`; performance / accessibility / best practices / SEO):
| Page | Scores |
|---|---|
| Home | 98 / 96 / 100 / 100 (desktop 99 / 96 / 100 / 100; LCP 2.2 s, TBT 0 ms, CLS 0) |
| Privacy, Terms, Support, Open source, Changelog, Delete account, 404 | 100 / 100 / 100 / 100 each |

Home's accessibility 96: the hero phone keeps the app's white-on-ember "27" and Save (fidelity).

**Tests:** `npm test` → build + 13 checks (headers, hashes, per-page meta/footer/no tracking, CTA gating, robots/sitemap/OG, tokens sync, legal content). `/vibesec`: no findings.

## Part 4 — Xcode Cloud → TestFlight

**Built**
- `ios/ci_scripts/ci_post_clone.sh`: installs XcodeGen with Homebrew, generates the project, prints versions, fails loudly.
- Build number from `CI_BUILD_NUMBER` (git commit count locally) via generated `ios/Config/BuildNumber.xcconfig`; marketing version 0.1.0.
- `ITSAppUsesNonExemptEncryption = NO` (CryptoKit + HTTPS only; verified against Apple's current pages), `PrivacyInfo.xcprivacy`, `scripts/testflight.sh` fallback.
- Local signed Release archive + App Store export succeeded ("iOS Team Store Provisioning Profile: com.devilsense.folio").
- Workflow "TestFlight": starts only on tags `testflight-*` (+ manual), Archive – iOS → TestFlight (Internal Testing Only) → group Owner. Owner's budget: about two builds across all phases.
- **Build 1 = 0.1.0 (1)** from tag `testflight-0.1.0`: archived in ~4 min on Xcode Cloud, in TestFlight and installed on the owner's iPhone. Its 3 compiler warnings were fixed afterwards (`c317855`, no new build).

## Screenshots (one line each)

| File | Shows |
|---|---|
| 00-contact-sheet.png | All screenshots below |
| 01-task-composer-date-title-visible.png | Date on: form at its top, Title visible, full picker, chips without panel |
| 02-profile-writing-since-earliest-day.png | "Writing since January 2024" from the earliest sample day |
| 03-todo-quick-add-inline-minimised-tab-bar.png | Quick-add beside the minimised tab bar, no gap |
| 05-recently-deleted-entries.png | Recently Deleted, Entries, days left |
| 05b-recently-deleted-entries-dark.png | Same, dark |
| 06-profile-recently-deleted-row.png | Profile → Your data: Recently Deleted · 5 and the export toggle |
| 07-recently-deleted-preview.png | Read-only preview with Restore / Delete now |
| 08-recently-deleted-tasks.png | Tasks segment: completed task stays ticked; "3 days left" in red |
| 09-swipe-restore.png | Leading swipe: Restore |
| 09b-swipe-delete-now.png | Trailing swipe: Delete now |
| 09c-select-mode.png | Select mode with Restore selected / Delete selected |
| 10-recently-deleted-empty.png | Empty state |
| 11-delete-toast.png | "Moved to Recently Deleted · Undo" on To-do |
| 12-restore-toast.png | "Restored to Mon 26 Oct · Show" |
| 13-web-home-desktop-light.png | Website home, desktop, light (hero mid-typing) |
| 13b-web-home-desktop-light-full.png | Website home, full page |
| 14-web-home-desktop-dark.png | Website home, desktop, dark (photo tile saved) |
| 15-web-home-mobile-light.png | Website home, mobile, light |
| 16-web-home-mobile-dark.png | Website home, mobile, dark |
| 17-web-privacy.png | Privacy policy |
| 18-web-support.png | Support FAQ, dark |
| 19-web-404.png | 404 |
| 20-release-sync-step-guest-only.png | Release build: sync step shows only Continue |
| rec-delete-recently-deleted-restore.mp4 | Delete → toast → Recently Deleted → Restore → Show (356 KB) |
| rec-website-hero-animation.mp4 | Website hero loop (136 KB) |
