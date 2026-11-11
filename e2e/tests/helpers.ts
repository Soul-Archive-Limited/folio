import { readFileSync } from 'node:fs';
import { expect, type ConsoleMessage, type Page } from '@playwright/test';

export const REVIEW_EMAIL = 'review@devilsense.com';

/** The local review code: `REVIEW_CODE` in CI, else the git-ignored api/.dev.vars (never committed). */
export function reviewCode(): string {
  if (process.env.REVIEW_CODE) return process.env.REVIEW_CODE;
  const vars = readFileSync(new URL('../../api/.dev.vars', import.meta.url), 'utf8');
  const line = vars.split('\n').find((l) => l.startsWith('REVIEW_CODE='));
  if (!line) throw new Error('REVIEW_CODE missing from api/.dev.vars');
  return line.slice('REVIEW_CODE='.length).trim();
}

/** Email sign-in with the review code; returns after the code is accepted. */
export async function signInWithEmail(page: Page) {
  await page.goto('/app');
  await page.getByRole('checkbox', { name: /18 or older/ }).check();
  await page.getByRole('button', { name: 'Continue with email' }).click();
  await page.getByLabel('Email address').fill(REVIEW_EMAIL);
  const send = page.getByRole('button', { name: 'Send code' });
  await expect(send).toBeEnabled({ timeout: 20_000 }); // Turnstile's always-pass test key
  await send.click();
  // Six digits submit by themselves.
  await page.getByLabel('Six-digit code').fill(reviewCode());
  await expect(page.getByLabel('Six-digit code')).toBeHidden({ timeout: 30_000 });
}

/** A brand-new account: sign in, read the recovery key, confirm it, optionally trust the browser. */
export async function signInNewAccount(page: Page, { trust }: { trust: boolean }): Promise<string> {
  await signInWithEmail(page);
  const box = page.locator('.recovery');
  await expect(box).toBeVisible({ timeout: 30_000 });
  const key = (await box.innerText()).replace(/\s+/g, '-').trim();
  await page.getByPlaceholder('Last 4').fill(key.replace(/-/g, '').slice(-4));
  if (trust) await page.getByRole('checkbox', { name: /Trust this browser/ }).check();
  await page.getByRole('button', { name: 'Continue' }).click();
  // The first-run welcome: skip it.
  const skip = page.getByRole('button', { name: /^Skip/ });
  if (await skip.isVisible({ timeout: 8_000 }).catch(() => false)) await skip.click();
  return key;
}

/** Collects console errors and warnings (and page errors) for the "zero console noise" checks. */
export function watchConsole(page: Page): string[] {
  const problems: string[] = [];
  page.on('console', (message: ConsoleMessage) => {
    if (message.type() === 'error' || message.type() === 'warning') problems.push(`${message.type()}: ${message.text()}`);
  });
  page.on('pageerror', (error) => problems.push(`pageerror: ${error.message}`));
  return problems;
}

export const recoveryKey = () => readFileSync(new URL('../.auth/recovery-key.txt', import.meta.url), 'utf8').trim();

/** Unlocks with the recovery key when the browser asks (the saved session cookie skips sign-in). */
export async function unlock(page: Page) {
  await page.getByRole('button', { name: 'Use recovery key' }).click();
  await page.getByLabel('Recovery key').fill(recoveryKey());
  await page.getByRole('button', { name: 'Unlock' }).click();
}

/** Opens the diary and waits for the app shell. A trusted key can't be carried between browser
 *  contexts (it's a non-extractable CryptoKey), so each test unlocks with the recovery key. */
export async function openDiary(page: Page, path = '/app') {
  await page.goto(path);
  const main = page.locator('.main');
  const locked = page.getByRole('heading', { name: 'Unlock your diary' });
  await expect(main.or(locked)).toBeVisible({ timeout: 30_000 });
  if (await locked.isVisible()) await unlock(page);
  await expect(main).toBeVisible({ timeout: 30_000 });
  const skip = page.getByRole('button', { name: /^Skip/ });
  if (await skip.isVisible({ timeout: 1_500 }).catch(() => false)) await skip.click();
}

/** In-app navigation (the diary key lives in memory; reloads re-open it from the trusted copy). */
export async function go(page: Page, path: string) {
  await page.evaluate((to) => {
    history.pushState({}, '', to);
    dispatchEvent(new PopStateEvent('popstate'));
  }, path);
}
