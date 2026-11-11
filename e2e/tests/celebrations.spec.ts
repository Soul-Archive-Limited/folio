import { expect, type Page, test } from '@playwright/test';
import { go, openDiary, watchConsole } from './helpers.ts';

// Batch N Part 4: gentle celebrations — the first page for a day blooms, finishing a day's
// tasks fills its ring with a sparkle; no streaks or counters; off switch in Appearance.
const cell = (page: Page, day: string) => page.locator(`.cell[data-day="${day}"]`).first();

async function writePage(page: Page, title: string) {
  await page.keyboard.press('n');
  await page.getByLabel('Title').first().fill(title);
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.locator('.sheet')).toHaveCount(0);
}

test.describe.serial('Celebrations', () => {
  test('first page of the day: a quiet line and a bloom; the second page is a plain save', async ({ page }, info) => {
    test.skip(info.project.name !== 'desktop', 'keyboard shortcuts');
    const problems = watchConsole(page);
    await openDiary(page);
    // A day with nothing on it yet (the seed wrote today's page).
    await page.locator('.cell:not(.out)').nth(19).click();
    const day = (await page.locator('.cell.selected').first().getAttribute('data-day'))!;
    await writePage(page, 'First light');
    await expect(page.getByText(/^(Today's page is kept\.|Kept on .+\.|Saved for .+\.)$/)).toBeVisible();
    await expect(cell(page, day)).toHaveClass(/celebrate-bloom/);
    await expect(cell(page, day)).not.toHaveClass(/celebrate-bloom/, { timeout: 3_000 });
    await writePage(page, 'Second thought');
    await expect(page.getByText(/^Saved to /)).toBeVisible();
    expect(problems).toEqual([]);
  });

  test("ticking a day's last task fills the ring with a sparkle", async ({ page }, info) => {
    test.skip(info.project.name !== 'desktop', 'keyboard shortcuts');
    await openDiary(page);
    // A day with no tasks yet (the seed put two open ones on today).
    await page.locator('.cell:not(.out)').nth(20).click();
    const day = (await page.locator('.cell.selected').first().getAttribute('data-day'))!;
    for (const title of ['Post the letter', 'Water the herbs']) {
      await page.keyboard.press('t');
      await page.getByLabel('Title').last().fill(title);
      await page.getByRole('button', { name: 'Save' }).click();
      await expect(page.locator('.sheet')).toHaveCount(0);
    }
    await page.getByRole('checkbox', { name: 'Post the letter' }).click();
    await expect(cell(page, day)).not.toHaveClass(/celebrate-tasksDone/);
    await page.getByRole('checkbox', { name: 'Water the herbs' }).click();
    await expect(cell(page, day)).toHaveClass(/celebrate-tasksDone/);
    await expect(cell(page, day).locator('.ring.done')).toBeVisible();
  });

  test('Celebrations off in Appearance: the page is saved plainly', async ({ page }, info) => {
    test.skip(info.project.name !== 'desktop', 'keyboard shortcuts');
    await openDiary(page);
    await go(page, '/app/profile/appearance');
    await page.getByRole('checkbox', { name: 'Celebrations' }).uncheck();
    await go(page, '/app');
    await page.locator('.cell:not(.out)').filter({ hasNotText: /^$/ }).nth(2).click();
    const day = await page.locator('.cell.selected').first().getAttribute('data-day');
    await writePage(page, 'Quiet one');
    await expect(page.getByText(/^Saved to /)).toBeVisible();
    await expect(cell(page, day!)).not.toHaveClass(/celebrate-/);
    await go(page, '/app/profile/appearance');
    await page.getByRole('checkbox', { name: 'Celebrations' }).check();
  });

  test('reduced motion: the bloom is a simple fade', async ({ browser }, info) => {
    test.skip(info.project.name !== 'desktop', 'keyboard shortcuts');
    const context = await browser.newContext({ reducedMotion: 'reduce', storageState: '.auth/state.json', baseURL: info.project.use.baseURL });
    const page = await context.newPage();
    await openDiary(page);
    await page.locator('.cell:not(.out)').nth(4).click();
    const day = await page.locator('.cell.selected').first().getAttribute('data-day');
    await writePage(page, 'Gentle');
    await expect(cell(page, day!)).toHaveClass(/celebrate-/);
    const animation = await cell(page, day!).evaluate((el) => getComputedStyle(el, '::after').animationName);
    expect(animation).toBe('cell-fade');
    await context.close();
  });
});
