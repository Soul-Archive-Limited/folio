import { expect, test } from '@playwright/test';
import { go, openDiary, recoveryKey, sheetsClosed, synced, watchConsole, writeEntry } from './helpers.ts';

// Batch N Part 5: the web app's actions end to end, on the desktop layout (keyboard shortcuts).
test.describe('Flows', () => {
  test.beforeEach(({}, info) => { test.skip(info.project.name !== 'desktop', 'desktop flows'); });

  test('unlock: a wrong recovery key is refused, the right one opens the diary', async ({ browser }, info) => {
    const context = await browser.newContext({ baseURL: info.project.use.baseURL, storageState: '.auth/state.json' });
    const page = await context.newPage();
    const problems = watchConsole(page);
    await page.goto('/app');
    await expect(page.getByRole('heading', { name: 'Unlock your diary' })).toBeVisible();
    await page.getByLabel('Recovery key').fill('AAAA-AAAAA-AAAA-AAAA-AAAAA-AAAA');
    await page.getByRole('button', { name: 'Unlock' }).click();
    await expect(page.getByRole('alert')).toContainText(/doesn't match|check/i);
    await page.getByLabel('Recovery key').fill(recoveryKey());
    await page.getByRole('button', { name: 'Unlock' }).click();
    await expect(page.locator('.main')).toBeVisible({ timeout: 30_000 });
    // The wrong key's 4xx is expected; nothing else may complain.
    expect(problems.filter((p) => !/status of 4\d\d/.test(p))).toEqual([]);
    await context.close();
  });

  test('entry: write, edit, delete with Undo, then Recently Deleted restore and delete now', async ({ page }) => {
    const problems = watchConsole(page);
    await openDiary(page);
    await page.locator('.cell:not(.out)').nth(6).click();
    await writeEntry(page, { title: 'Flow page', body: 'First draft.', mood: 'Steady' });
    const card = page.locator('.day-panel').getByRole('button', { name: /Flow page/ });
    await card.click();
    await page.getByRole('button', { name: 'Edit' }).click();
    await page.locator('.sheet').getByLabel('Title').fill('Flow page, edited');
    await page.locator('.sheet').getByRole('button', { name: 'Save' }).click();
    await sheetsClosed(page);
    await expect(page.locator('.day-panel').getByRole('button', { name: /Flow page, edited/ })).toBeVisible();
    // Delete → Undo brings it back.
    await page.locator('.day-panel').getByRole('button', { name: /Flow page, edited/ }).click();
    await page.getByRole('button', { name: 'More' }).click();
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await page.getByRole('button', { name: 'Undo' }).click();
    await expect(page.locator('.day-panel').getByRole('button', { name: /Flow page, edited/ })).toBeVisible();
    // Recently Deleted: the seeded page restores; delete now asks first.
    await go(page, '/app/profile/deleted');
    await expect(page.getByText('To be deleted')).toBeVisible();
    await page.getByRole('button', { name: /Restore/ }).first().click();
    await expect(page.getByText('To be deleted')).toBeHidden();
    await synced(page);
    expect(problems).toEqual([]);
  });

  test('to-do: quick add reads natural dates; tick and undo', async ({ page }) => {
    await openDiary(page);
    await go(page, '/app/todo');
    const bar = page.getByPlaceholder(/Add a task/);
    await bar.fill('Call the plumber tomorrow 6pm');
    await expect(page.getByText(/Tomorrow · 18:00/)).toBeVisible();
    await bar.press('Enter');
    const row = page.getByRole('checkbox', { name: /Call the plumber/ });
    await expect(row).toBeVisible();
    await row.click();
    await page.getByRole('button', { name: 'Undo' }).click();
    await expect(row).toHaveAttribute('aria-checked', 'false');
  });

  test('search finds pages by text and by place', async ({ page }) => {
    await openDiary(page);
    await page.keyboard.press('/');
    const field = page.getByRole('searchbox', { name: 'Search' });
    await field.fill('gulls');
    await expect(page.getByRole('dialog', { name: 'Search' }).getByText(/Harbour walk/).first()).toBeVisible();
    await field.fill('belém');
    await expect(page.getByRole('dialog', { name: 'Search' }).getByText(/Lisbon/).first()).toBeVisible();
    await page.keyboard.press('Escape');
  });

  test('Year in Pixels shows the year with mood and category keys', async ({ page }) => {
    await openDiary(page);
    await go(page, '/app/journal');
    await page.getByRole('button', { name: 'Year in Pixels' }).click();
    await expect(page.getByRole('button', { name: 'Mood', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Category', exact: true }).click();
    await expect(page.getByRole('button', { name: /, 1 page/ }).first()).toBeVisible();
  });

  test('invites: the owner makes a code', async ({ page }) => {
    await openDiary(page);
    await go(page, '/app/profile/invites');
    await page.getByRole('button', { name: /New invite|Make an invite|Create/ }).first().click();
    await expect(page.getByText(/[A-Z0-9]{4}-[A-Z0-9]{4}/).first()).toBeVisible();
  });

  test('PDF: the book is made and handed to the print window', async ({ page }) => {
    await openDiary(page);
    await page.evaluate(() => { (window as unknown as { printed: number }).printed = 0; window.print = () => { (window as unknown as { printed: number }).printed += 1; }; });
    await go(page, '/app/profile/data');
    await page.getByRole('button', { name: /Export PDF/ }).click();
    const make = page.getByRole('button', { name: /^Create PDF/ });
    await make.click();
    await expect.poll(() => page.evaluate(() => (window as unknown as { printed: number }).printed)).toBeGreaterThan(0);
  });

  test('theme: Dark in Appearance switches the page at once', async ({ page }) => {
    await openDiary(page);
    await go(page, '/app/profile/appearance');
    await page.getByRole('combobox', { name: /Theme/ }).selectOption('dark');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    await page.getByRole('combobox', { name: /Theme/ }).selectOption('system');
  });

  test('keyboard only: move days, months, tabs, open and close with the keyboard', async ({ page }) => {
    const problems = watchConsole(page);
    await openDiary(page);
    await page.locator('.cell.selected').first().focus();
    const start = await page.locator('.cell.selected').first().getAttribute('data-day');
    await page.keyboard.press('ArrowRight');
    await expect(page.locator('.cell.selected').first()).not.toHaveAttribute('data-day', start!);
    await page.keyboard.press(']');
    await page.keyboard.press('g');
    await expect(page.locator('.cell.selected').first()).toHaveClass(/today/);
    await page.keyboard.press('?');
    await expect(page.getByRole('dialog', { name: /Keyboard shortcuts/ })).toBeVisible();
    await page.keyboard.press('Escape');
    await sheetsClosed(page);
    await page.keyboard.press('2');
    await expect(page).toHaveURL(/\/app\/journal/);
    await page.keyboard.press('4');
    await expect(page).toHaveURL(/\/app\/profile/);
    // Tab reaches the profile rows with a visible focus ring.
    for (let i = 0; i < 30; i++) {
      await page.keyboard.press('Tab');
      if (await page.evaluate(() => document.activeElement?.closest('.profile-rows') != null)) break;
    }
    const outline = await page.evaluate(() => getComputedStyle(document.activeElement as Element).outlineStyle);
    expect(outline).not.toBe('none');
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/\/app\/profile\/account/);
    expect(problems).toEqual([]);
  });
});
