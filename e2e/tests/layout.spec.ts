import AxeBuilder from '@axe-core/playwright';
import { expect, type Page, test } from '@playwright/test';
import { go, openDiary, projectContext, sheetsClosed, watchConsole } from './helpers.ts';

/**
 * Every screen of the web app at this project's width (desktop, phone, iPad): no console errors
 * or warnings, axe with no serious or critical issues, and a screenshot in light and dark
 * (Batch N Part 5). axe runs in its own context with the CSP bypassed (the CSP rightly blocks
 * its injected script); console checks run with the real CSP.
 */
type Screen = { name: string; open: (page: Page) => Promise<void> };

const screens: Screen[] = [
  { name: 'calendar', open: async () => {} },
  { name: 'day-panel', open: async (page) => { await page.locator('.cell.today').first().click(); } },
  { name: 'entry', open: async (page) => { await go(page, '/app/journal'); await page.getByRole('button', { name: /Harbour walk/ }).first().click(); } },
  { name: 'composer', open: async (page) => { await page.getByRole('button', { name: /New entry|New page|Write/ }).first().click().catch(() => page.keyboard.press('n')); } },
  { name: 'journal', open: async (page) => { await go(page, '/app/journal'); } },
  { name: 'journal-photos', open: async (page) => { await go(page, '/app/journal'); await page.getByRole('button', { name: 'Photos' }).click(); } },
  { name: 'journal-year', open: async (page) => { await go(page, '/app/journal'); await page.getByRole('button', { name: 'Year in Pixels' }).click(); } },
  { name: 'journal-places', open: async (page) => { await go(page, '/app/journal'); await page.getByRole('button', { name: 'Places' }).click(); } },
  { name: 'todo', open: async (page) => { await go(page, '/app/todo'); } },
  { name: 'search', open: async (page) => { await page.keyboard.press('/'); await page.getByRole('searchbox', { name: 'Search' }).fill('harbour'); } },
  { name: 'profile', open: async (page) => { await go(page, '/app/profile'); } },
  { name: 'profile-account', open: async (page) => { await go(page, '/app/profile/account'); } },
  { name: 'profile-appearance', open: async (page) => { await go(page, '/app/profile/appearance'); } },
  { name: 'profile-data', open: async (page) => { await go(page, '/app/profile/data'); } },
  { name: 'profile-help', open: async (page) => { await go(page, '/app/profile/help'); } },
  { name: 'devices', open: async (page) => { await go(page, '/app/profile/devices'); } },
  { name: 'invites', open: async (page) => { await go(page, '/app/profile/invites'); } },
  { name: 'categories', open: async (page) => { await go(page, '/app/profile/categories'); } },
  { name: 'recently-deleted', open: async (page) => { await go(page, '/app/profile/deleted'); } },
  { name: 'edit-profile', open: async (page) => { await go(page, '/app/profile'); await page.getByRole('button', { name: 'Edit profile' }).last().click(); } },
];

/** Back to a resting calendar between screens (no sheet, popover or search open). */
async function reset(page: Page) {
  for (let i = 0; i < 3; i++) await page.keyboard.press('Escape');
  await sheetsClosed(page);
  await go(page, '/app');
}

// One unlocked page per run: every unlock opens a device-link request, and the API rate-limits
// those (as it should), so a fresh unlock per screen would trip it.
test.describe.serial('Screens', () => {
  let page: Page;
  let problems: string[];
  test.beforeAll(async ({ browser }, info) => {
    page = await (await projectContext(browser, info)).newPage();
    problems = watchConsole(page);
    await openDiary(page);
  });
  test.afterAll(async () => { await page.context().close(); });

  for (const scheme of ['light', 'dark'] as const) {
    for (const screen of screens) {
      test(`${scheme} ${screen.name}: no console noise`, async ({}, info) => {
        problems.length = 0;
        await page.emulateMedia({ colorScheme: scheme });
        await reset(page);
        await screen.open(page);
        await page.waitForTimeout(600); // let entrances settle
        await page.screenshot({ path: `test-results/screens/${info.project.name}-${scheme}-${screen.name}.png` });
        expect(problems, 'console errors or warnings').toEqual([]);
      });
    }
  }
});

test.describe.serial('Accessibility (axe)', () => {
  let page: Page;
  test.beforeAll(async ({ browser }, info) => {
    page = await (await projectContext(browser, info, { bypassCSP: true })).newPage();
    await openDiary(page);
  });
  test.afterAll(async () => { await page.context().close(); });

  for (const scheme of ['light', 'dark'] as const) {
    for (const screen of screens) {
      test(`${scheme} ${screen.name}: axe 0 serious`, async ({}, info) => {
        test.skip(info.project.name === 'ipad' && scheme === 'dark', 'covered by desktop and phone');
        await page.emulateMedia({ colorScheme: scheme });
        await reset(page);
        await screen.open(page);
        await page.waitForTimeout(600);
        const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']).analyze();
        const serious = results.violations.filter((v) => v.impact === 'serious' || v.impact === 'critical');
        expect(serious.map((v) => `${v.id}: ${v.nodes.map((n) => `${n.target.join(' ')} ${n.any[0]?.message ?? ''}`).slice(0, 3).join(' | ')}`)).toEqual([]);
      });
    }
  }
});
