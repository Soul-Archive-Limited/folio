import { readFileSync } from 'node:fs';
import { type Browser, type BrowserContext, type BrowserContextOptions, expect, type ConsoleMessage, type Page, type TestInfo } from '@playwright/test';

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
  // The first-run welcome arrives a moment later: wait for it, then skip it.
  const skip = page.getByRole('button', { name: /^Skip/ });
  if (await skip.waitFor({ state: 'visible', timeout: 10_000 }).then(() => true, () => false)) await skip.click();
  await expect(skip).toBeHidden();
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
  const tab = page.getByRole('button', { name: 'Use recovery key' });
  if ((await tab.getAttribute('aria-pressed')) !== 'true') await tab.click();
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
  if (await skip.waitFor({ state: 'visible', timeout: 1_500 }).then(() => true, () => false)) await skip.click();
}

/** In-app navigation (the diary key lives in memory; reloads re-open it from the trusted copy). */
export async function go(page: Page, path: string) {
  await page.evaluate((to) => {
    history.pushState({}, '', to);
    dispatchEvent(new PopStateEvent('popstate'));
  }, path);
}

/** Waits until the diary has reached the server (the sidebar says "Up to date"), so a new
 *  browser context — the next test — sees this one's changes. Desktop layout only. */
export async function synced(page: Page) {
  await page.waitForTimeout(800);
  const status = page.locator('.sidebar .me');
  if (await status.isVisible()) await expect(status).toContainText('Up to date', { timeout: 20_000 });
  else await page.waitForTimeout(3_000); // phones: no status on screen; the push follows within a second
}

/** Waits until no sheet is open (each closes with a short animation). */
export async function sheetsClosed(page: Page) {
  await expect(page.locator('.sheet')).toHaveCount(0);
}

/** A page through the real composer: title, text, optional mood and place. */
export async function writeEntry(page: Page, { title, body, mood, place }: { title: string; body?: string; mood?: string; place?: string }) {
  await page.keyboard.press('n');
  const sheet = page.locator('.sheet');
  await sheet.getByLabel('Title').fill(title);
  if (body) {
    await sheet.getByRole('textbox', { name: /What (happened|do you remember)/ }).click();
    await page.keyboard.type(body);
  }
  if (mood) await sheet.getByRole('radio', { name: mood }).click();
  if (place) {
    await sheet.getByRole('button', { name: 'Add place' }).click();
    await sheet.getByLabel('Place name').fill(place);
    await sheet.getByRole('button', { name: 'Add', exact: true }).click();
  }
  await sheet.getByRole('button', { name: 'Save' }).click();
  await sheetsClosed(page);
}

/** A task through the task sheet (T). */
export async function addTask(page: Page, title: string) {
  await page.keyboard.press('t');
  await page.locator('.sheet').getByLabel('Title').fill(title);
  await page.locator('.sheet').getByRole('button', { name: 'Save' }).click();
  await sheetsClosed(page);
}

/** Selects a day of the shown month by its day number (1–28). */
export async function selectDay(page: Page, n: number) {
  await page.locator('.cell:not(.out)').nth(n - 1).click();
}

/** A context like this project's (viewport, touch, mobile, base URL, saved session). */
export async function projectContext(browser: Browser, info: TestInfo, extra: BrowserContextOptions = {}): Promise<BrowserContext> {
  const use = info.project.use;
  return browser.newContext({
    baseURL: use.baseURL, viewport: use.viewport, userAgent: use.userAgent, deviceScaleFactor: use.deviceScaleFactor,
    isMobile: use.isMobile, hasTouch: use.hasTouch, storageState: '.auth/state.json', ...extra,
  });
}
