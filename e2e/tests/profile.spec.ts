import { expect, test } from '@playwright/test';
import { go, openDiary, watchConsole } from './helpers.ts';

// Batch N Parts 2–3: Profile's structure, search and Edit profile.
test.describe('Profile', () => {
  test('root: card, four stats, grouped rows; each row opens its page', async ({ page }, info) => {
    const problems = watchConsole(page);
    await openDiary(page);
    await go(page, '/app/profile');
    await expect(page.getByRole('heading', { name: 'Profile', level: 1 })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Edit profile' }).last()).toBeVisible();
    for (const stat of ['Pages', 'Days written on', 'Photos', 'Tasks done']) await expect(page.locator('.stats-row').getByText(stat)).toBeVisible();
    const pages = ['Account & Sync', 'Categories', 'Appearance', 'Writing & Dictation', 'Reminders & Notifications', 'Widgets', 'Privacy & Security', 'Your data', 'Help & About'];
    for (const title of pages) {
      await page.locator('.profile-rows').getByRole('button', { name: title }).click();
      await expect(page.getByRole('heading', { name: title, level: 1 }).last()).toBeVisible();
      // Phones show one column; from 768 px the rows stay beside the page.
      if (await page.locator('.profile-root').isHidden()) await page.getByRole('button', { name: 'Back to Profile' }).click();
    }
    await page.screenshot({ path: `test-results/profile-${info.project.name}.png` });
    expect(problems).toEqual([]);
  });

  test('search finds any setting and opens its page', async ({ page }) => {
    await openDiary(page);
    await go(page, '/app/profile');
    await page.getByPlaceholder('Search settings').fill('dark');
    await page.getByRole('group', { name: 'Matching settings' }).getByRole('button', { name: /Theme/ }).click();
    await expect(page.getByRole('heading', { name: 'Appearance', level: 1 })).toBeVisible();
    await go(page, '/app/profile');
    await page.getByPlaceholder('Search settings').fill('zzzz');
    await expect(page.getByText('No settings match “zzzz”.')).toBeVisible();
  });

  test('Edit profile: Folio avatar and name save and show at once', async ({ page }) => {
    await openDiary(page);
    await go(page, '/app/profile');
    await page.getByRole('button', { name: 'Edit profile' }).last().click();
    const sheet = page.getByRole('dialog', { name: 'Edit profile' });
    await sheet.getByRole('button', { name: 'Folio avatars' }).click();
    await sheet.getByRole('option', { name: 'Avatar 7' }).click();
    await sheet.getByPlaceholder('Your name').fill('Sam Review');
    await sheet.getByRole('button', { name: 'Save' }).click();
    await expect(page.locator('.profile-card').getByText('Sam Review')).toBeVisible();
    await expect(page.locator('.profile-card img[src$="avatar-07.svg"]')).toBeVisible();
    // Cancel leaves everything as it was.
    await page.getByRole('button', { name: 'Edit profile' }).last().click();
    await sheet.getByPlaceholder('Your name').fill('Nobody');
    await sheet.getByRole('button', { name: 'Cancel' }).click();
    await expect(page.locator('.profile-card').getByText('Sam Review')).toBeVisible();
  });
});
