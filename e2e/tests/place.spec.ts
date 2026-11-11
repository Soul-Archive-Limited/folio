import { expect, test } from '@playwright/test';
import { openDiary, sheetsClosed, synced, watchConsole } from './helpers.ts';

// Batch N Part 1 on the web: places by name, recents, Apple Maps link, removal.
test.describe('Places', () => {
  test('add by name, pick a recent one, open in Apple Maps, remove', async ({ page }, info) => {
    test.skip(info.project.name === 'ipad', 'desktop and phone');
    const problems = watchConsole(page);
    await openDiary(page);
    await page.locator('.day-panel').getByRole('button', { name: /Harbour walk/ }).first().click();
    const link = page.getByRole('link', { name: /Open in Apple Maps/ });
    await expect(link).toHaveAttribute('href', /^https:\/\/maps\.apple\.com\/\?q=Tate\+Modern$/);
    await expect(link).toHaveAttribute('rel', /noopener/);
    await expect(link).toHaveAttribute('target', '_blank');
    // Edit: the chip shows the place; × removes it; a recent place comes back with one tap.
    await page.getByRole('button', { name: 'Edit' }).click();
    const sheet = page.locator('.sheet');
    await sheet.getByRole('button', { name: 'Remove place' }).click();
    await expect(sheet.getByText('Tate Modern')).toBeHidden();
    await sheet.getByRole('button', { name: 'Add place' }).click();
    await sheet.getByRole('group', { name: 'Recent places' }).getByRole('button', { name: 'Belém' }).click();
    await sheet.getByRole('button', { name: 'Save' }).click();
    await sheetsClosed(page);
    await expect(page.locator('.day-panel').getByLabel('Place, Belém')).toBeVisible();
    // Put it back as it was for the other tests.
    await page.locator('.day-panel').getByRole('button', { name: /Harbour walk/ }).first().click();
    await page.getByRole('button', { name: 'Edit' }).click();
    await sheet.getByRole('button', { name: 'Place, Belém. Change' }).click();
    await sheet.getByLabel('Place name').fill('Tate Modern');
    await sheet.getByRole('button', { name: 'Add', exact: true }).click();
    await sheet.getByRole('button', { name: 'Save' }).click();
    await sheetsClosed(page);
    await synced(page);
    expect(problems).toEqual([]);
  });
});
