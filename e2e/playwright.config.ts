import { existsSync } from 'node:fs';
import { defineConfig, devices } from '@playwright/test';

/**
 * Folio's web app end to end (Batch N Part 5). Runs against a local stack: the API with
 * `wrangler dev` on :8787 and the built site served by scripts/web-local-server.mjs on :8788
 * (see e2e/README.md). CI starts both; locally start them first.
 * There's no Chrome on the owner's Mac, so Brave is used when it's there; CI uses Playwright's Chromium.
 */
const brave = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';
const launchOptions = !process.env.CI && existsSync(brave) ? { executablePath: brave } : {};

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : [['list']],
  globalSetup: './global-setup.ts',
  use: {
    baseURL: process.env.FOLIO_WEB ?? 'http://localhost:8788',
    storageState: '.auth/state.json',
    trace: 'retain-on-failure',
    launchOptions,
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 860 }, launchOptions } },
    { name: 'phone', use: { ...devices['Pixel 7'], launchOptions }, testMatch: /layout|celebrations|profile|place/ },
    { name: 'ipad', use: { viewport: { width: 820, height: 1180 }, hasTouch: true, launchOptions }, testMatch: /layout|profile/ },
  ],
});
