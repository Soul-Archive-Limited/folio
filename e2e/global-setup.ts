import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { chromium, type FullConfig } from '@playwright/test';
import { signInNewAccount } from './tests/helpers.ts';

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
  await page.getByRole('heading', { name: /calendar|november|december|january/i }).first().waitFor({ timeout: 30_000 }).catch(() => {});
  await context.storageState({ path: '.auth/state.json', indexedDB: true });
  await browser.close();
}
