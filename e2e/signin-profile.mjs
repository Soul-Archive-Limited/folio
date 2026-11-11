// Signs a persistent Brave profile in to the local web app for the sync matrix (Batch N):
// email + the local review code (REVIEW_CODE env), then unlock with the recovery key (RECOVERY_KEY
// env) and trust the browser. Nothing is written except the browser profile itself.
//   REVIEW_CODE=… RECOVERY_KEY=… node e2e/signin-profile.mjs <profile-dir> [http://localhost:8788]
import { chromium } from '@playwright/test';

const [dir, web = 'http://localhost:8788'] = process.argv.slice(2);
const context = await chromium.launchPersistentContext(dir, {
  executablePath: '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser', viewport: { width: 1440, height: 900 },
});
const page = context.pages()[0] ?? await context.newPage();
await page.goto(`${web}/app`);
await page.getByRole('checkbox', { name: /18 or older/ }).check();
await page.getByRole('button', { name: 'Continue with email' }).click();
await page.getByLabel('Email address').fill('review@devilsense.com');
const send = page.getByRole('button', { name: 'Send code' });
await send.waitFor();
for (let i = 0; i < 100 && !(await send.isEnabled()); i++) await page.waitForTimeout(200);
await send.click();
await page.getByLabel('Six-digit code').fill(process.env.REVIEW_CODE);
await page.getByRole('heading', { name: 'Unlock your diary' }).waitFor({ timeout: 30_000 });
await page.getByRole('button', { name: 'Use recovery key' }).click();
await page.getByLabel('Recovery key').fill(process.env.RECOVERY_KEY);
await page.getByRole('checkbox', { name: /Trust this browser/ }).check();
await page.getByRole('button', { name: 'Unlock' }).click();
await page.locator('.main').waitFor({ timeout: 30_000 });
const skip = page.getByRole('button', { name: /^Skip/ });
if (await skip.waitFor({ timeout: 8_000 }).then(() => true, () => false)) await skip.click();
await page.waitForTimeout(1500);
await context.close();
console.log(`signed in: ${dir}`);
