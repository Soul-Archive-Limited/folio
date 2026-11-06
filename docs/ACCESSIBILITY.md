# Folio — accessibility (WCAG 2.2 AA), Batch L

_6 November 2026. Website, web app and iPhone app. Public statement: `/accessibility`._

## Summary

| Surface | Method | Result |
|---|---|---|
| Website (19 pages) | axe-core 4.11 with WCAG 2.0/2.1/2.2 A + AA and best-practice rules, light and dark, reduced motion | **0 issues of any impact** on every page in both themes (after one fix) |
| Web app (sign-in, email step, calendar, entry, composer, journal, year, photos, to-do, profile, shortcuts, Recently Deleted, search) | same, signed in with the sample diary, light and dark | **0 serious/critical**; 0 moderate after the search-heading fix (was 2 × `heading-order`) |
| Keyboard | Tab through the home page, Features, Privacy, FAQ, sign-in, calendar and To-do; record each stop's focus style and name | Every stop has a visible focus style (2.5 px Ink outline) and an accessible name; ≥ 24 × 24 px targets; N / ? / 1–4 shortcuts work |
| Contrast | Build check on design tokens (`web/scripts/check-build.mjs`: accent text and fills ≥ 4.5:1) + axe on rendered pages | Pass |
| iPhone | Xcode accessibility audit (`performAccessibilityAudit`) on 15 screens at the default text size and at AX5; VoiceOver labels in code review | See "iPhone" below |

Raw axe results: `docs/reports/batch-l-axe.json` (64 page states).

## Findings and fixes (this batch)

1. **Tertiary text below 4.5:1** (web app: weekday row, out-of-month day numbers, captions, "Writing since", small row notes, Year in Pixels day numbers). The 34–36 % tertiary ink is fine for marks but not for words. New `--ink-quiet` (a solid mix: 66 % ink on paper, 84 % on charcoal) for quiet text, `--ink-label` for the weekday row; the tertiary token stays for outlines and dots. In dark mode axe measures text on translucent glass against the aura blobs' full colour, so labels carry more weight there to pass even in that worst case.
2. **Primary buttons in dark mode** used the light Ink (#949FFF) under white text (2.6:1). They now use `accentStrong` (#4551D3, 6.2:1), as SPEC §3.2 intends for fills under white.
3. **Danger text** ("Delete account") was 4.31:1 in light; `--danger-text` mixes the red toward the text colour in each theme (≥ 5:1).
4. **Active sidebar item in dark mode** (Ink text on an Ink tint, 4.4:1): the label is now the text colour, the icon keeps the Ink.
5. **Calendar grid semantics:** `role="grid"` had cells without rows (`aria-required-children` / `aria-required-parent` × 42). Weeks are now `role="row"` wrappers with `display: contents`, so the layout is unchanged and arrow-key navigation still moves between days. Year in Pixels is now a labelled group of buttons (each button names its date, page count and mood) instead of an incomplete grid.
6. **Page without a level-one heading** (calendar view): a visually hidden "Calendar" `h1`. Search result headings changed from `h3` to `h2`.
7. **To-do quick-add bar covering rows** (`target-size`: a tick obscured to 26 × 15 px; also WCAG 2.4.11 Focus Not Obscured): on screens ≥ 768 px the bar now sits below the list instead of floating over it. Phones keep the floating bar (the list has room to scroll every row clear of it).
8. **Website home in dark mode:** the "Make it yours" season words used tertiary ink; now the secondary text colour.

## Requirements checklist

| WCAG 2.2 AA area | Website | Web app | iPhone |
|---|---|---|---|
| 1.1.1 Text alternatives | Every content image has alt text describing the screenshot; decorative images `alt=""` / `aria-hidden` | Photos in entries: the entry's own words (photos you add have no description — stated as a known limitation); icons have labels | Every control labelled; decorative images hidden |
| 1.3.1 Info and relationships | Landmarks, one `h1` per page, ordered headings, lists, `dl` for facts, tables with headers | Grid → row → cell; labelled groups; form labels | Headers traits; day cells speak the full date and counts; rotor "Days with entries" |
| 1.4.3 / 1.4.11 Contrast | axe 0; token check in the build | axe 0 serious | Measured from tokens (accent words ≥ 7:1, fills under white ≥ 6:1); glass audited by hand (DECISIONS 211) |
| 1.4.4 / 1.4.10 Resize, reflow | Fluid type with `clamp`, no horizontal scroll at 320 px | Phone layout below 768 px | Dynamic Type to AX5; calendar switches to week rows at AX sizes |
| 2.1.1 Keyboard | All controls are links/buttons; skip link | Full keyboard; shortcuts (`?`); dialogs close with Esc | Full Keyboard Access; iPad hardware shortcuts (⌘N, ⌘1–4, ⌘[ ⌘], ⌘F, ⌘↩) |
| 2.3.3 / reduced motion | `prefers-reduced-motion`: no 3D, no season layer, no scroll-driven motion, fades only | Same; animations become ≤ 0.2 s fades | Reduce Motion: cross-fades only; season layer off |
| 2.4.3 / 2.4.7 Focus order and visible | Verified by tab-through | Verified by tab-through | System focus |
| 2.4.11 Focus not obscured | Sticky nav leaves `scroll-padding-top` | Quick-add moved out of the scroll area on wide screens | — |
| 2.5.8 Target size | ≥ 24 px (buttons 40–54 px) | axe target-size 0 | ≥ 44 pt |
| 3.3.1 / 3.3.2 Labels and errors | — | Labels on every field; errors in `role="alert"`; the 18+ box says why it's needed | Errors in plain words; VoiceOver hint on the 18+ box |
| 4.1.2 Name, role, value | axe 0 | `aria-pressed`, `aria-checked`, `aria-expanded` on toggles | Traits and values (e.g. 18+ box: "Ticked" / "Not ticked") |

## iPhone

See the run recorded below (filled in by the audit at the end of this batch).
