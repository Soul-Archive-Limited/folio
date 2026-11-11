import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { chromium, type FullConfig } from '@playwright/test';
import { addTask, selectDay, signInNewAccount, synced, writeEntry } from './tests/helpers.ts';
import type { Page } from '@playwright/test';

/**
 * Signs a fresh review account in through the real sign-in page (email + the local review code),
 * makes its recovery key, trusts the browser, and saves cookies + IndexedDB (the trusted key)
 * so every test opens the diary directly. The recovery key goes to `.auth/` for the unlock test.
 */
export default async function globalSetup(config: FullConfig) {
  const { baseURL, launchOptions } = config.projects[0]!.use;
  mkdirSync('.auth', { recursive: true });
  // A clean local database: no review account yet, no rate limits (local D1 only).
  if (process.env.FOLIO_E2E_RESET !== '0') execFileSync('./reset-local.sh', { stdio: 'inherit' });
  const browser = await chromium.launch(launchOptions);
  const context = await browser.newContext({ baseURL });
  const page = await context.newPage();
  const recoveryKey = await signInNewAccount(page, { trust: true });
  writeFileSync('.auth/recovery-key.txt', recoveryKey);
  await page.locator('.main').waitFor({ timeout: 30_000 });
  try {
    await seed(page);
  } catch (error) {
    await page.screenshot({ path: 'test-results/seed-failure.png' });
    throw error;
  }
  // Tests unlock with the recovery key: open the unlock screen on it (no device-link request,
  // which the API limits to 10 an hour).
  await page.evaluate(() => localStorage.setItem('folio.unlockMode', 'recovery'));
  await context.storageState({ path: '.auth/state.json', indexedDB: true });
  await browser.close();
}

/** A small diary through the real UI, so every screen has something to show. */
async function seed(page: Page) {
  await writeEntry(page, { title: 'Harbour walk', body: 'Gulls over the water, tea from a flask.', mood: 'Good', place: 'Tate Modern' });
  await addTask(page, 'Post the letter to Ana');
  await addTask(page, 'Book dentist');
  await selectDay(page, 3);
  await writeEntry(page, { title: 'Lisbon', body: 'Pastéis de nata for breakfast.', mood: 'Bright', place: 'Belém' });
  await selectDay(page, 2);
  await writeEntry(page, { title: 'To be deleted', body: 'This one goes to Recently Deleted.' });
  await page.locator('.day-panel').getByRole('button', { name: /To be deleted/ }).click();
  await page.getByRole('button', { name: 'More' }).click();
  await page.getByRole('menuitem', { name: 'Delete' }).click();
  await page.locator('.sheet').waitFor({ state: 'detached' });
  await synced(page);
}
