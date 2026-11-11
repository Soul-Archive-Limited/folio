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

export type CelebrationKind = 'bloom' | 'settle' | 'tasksDone';

/**
 * Plays a celebration on a calendar day, if it's on screen: a CSS class on `.cell[data-day]`
 * that the stylesheet animates (≤ 0.8 s; a fade under reduced motion) and removes after.
 * A new one on the same day restarts it, so nothing queues up.
 */
export function celebrate(kind: CelebrationKind, day: string) {
  if (!celebrationsOn() || typeof document === 'undefined') return;
  const cell = document.querySelector<HTMLElement>(`.cell[data-day="${CSS.escape(day)}"]`);
  if (!cell) return;
  const cls = `celebrate-${kind}`;
  cell.classList.remove('celebrate-bloom', 'celebrate-settle', 'celebrate-tasksDone');
  void cell.offsetWidth; // restart the animation
  cell.classList.add(cls);
  window.setTimeout(() => cell.classList.remove(cls), 1000);
}

/** The quiet line for the first page kept for a day. */
export function savedLine(day: string, today: string): string {
  if (day === today) return "Today's page is kept.";
  const date = new Intl.DateTimeFormat('en-GB', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC' }).format(new Date(`${day}T00:00:00Z`));
  return `Kept on ${date}.`;
}
