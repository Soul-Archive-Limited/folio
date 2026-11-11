# Folio web app — end-to-end tests

Playwright tests for `/app` against a **local** stack (Batch N). They sign in with the local
review code, create the diary's recovery key, seed a small diary through the UI, then visit every
screen at desktop, phone and iPad widths (no console errors or warnings; axe with no serious or
critical issues, light and dark) and run the main flows (entries, Recently Deleted, quick add,
search, places, Year in Pixels, invites, PDF, theme, keyboard only, celebrations, Profile).

```bash
cd api && npx wrangler dev --ip 127.0.0.1 --port 8787
```

```bash
cd web && npm run build && node ../scripts/web-local-server.mjs dist 8788
```

```bash
cd e2e && npm ci --ignore-scripts && npx playwright test
```

- `api/.dev.vars` (git-ignored) needs `REVIEW_CODE`, Cloudflare's test `TURNSTILE_SECRET` and an
  empty `TURNSTILE_HOSTNAME=`. The API needs network access for Turnstile's siteverify.
- `global-setup.ts` empties the **local** D1 first (`reset-local.sh`; set `FOLIO_E2E_RESET=0` to
  skip). It can never touch the deployed database.
- On the owner's Mac (no Chrome) the tests use Brave; CI uses Playwright's Chromium
  (`.github/workflows/e2e.yml`).
