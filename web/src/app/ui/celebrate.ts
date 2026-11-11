/**
 * Gentle celebrations (Batch N Part 4), the web's versions of the iPhone's: no streaks, no
 * counters, under a second, and only a fade with reduced motion. Kept per browser.
 */
const KEY = 'folio.celebrations';

export function celebrationsOn(): boolean {
  try { return localStorage.getItem(KEY) !== 'off'; } catch { return true; }
}

export function setCelebrations(on: boolean) {
  try { localStorage.setItem(KEY, on ? 'on' : 'off'); } catch { /* private mode */ }
}
