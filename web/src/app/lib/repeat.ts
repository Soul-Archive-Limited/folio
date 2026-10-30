/**
 * Repeating tasks (Batch I), the same rules as RepeatRule.swift: completing a repeating task
 * keeps it done on its day and adds the next one; a reminder moves by the same number of days.
 */
export interface RepeatRule { frequency: 'daily' | 'weekdays' | 'weekly' | 'monthly' | 'yearly' | 'custom'; interval?: number; unit?: 'day' | 'week' | 'month' }

const FREQUENCIES = ['daily', 'weekdays', 'weekly', 'monthly', 'yearly', 'custom'];

export function parseRule(json: string | undefined): RepeatRule | undefined {
  if (!json) return undefined;
  try {
    const rule = JSON.parse(json) as RepeatRule;
    return FREQUENCIES.includes(rule.frequency) ? rule : undefined;
  } catch { return undefined; }
}

const pad = (n: number) => String(n).padStart(2, '0');
const toKey = (d: Date) => `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
const fromKey = (key: string) => new Date(Date.UTC(Number(key.slice(0, 4)), Number(key.slice(5, 7)) - 1, Number(key.slice(8, 10))));

export function addDays(key: string, days: number): string {
  const d = fromKey(key);
  d.setUTCDate(d.getUTCDate() + days);
  return toKey(d);
}

/** Same day of the month, or the month's last day when it's shorter (31 Jan → 28 Feb). */
export function addMonths(key: string, months: number): string {
  const y = Number(key.slice(0, 4)), m = Number(key.slice(5, 7)) - 1 + months, day = Number(key.slice(8, 10));
  const year = y + Math.floor(m / 12), month = ((m % 12) + 12) % 12;
  const last = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return `${year}-${pad(month + 1)}-${pad(Math.min(day, last))}`;
}

export function nextDay(rule: RepeatRule, key: string): string {
  const n = Math.max(rule.interval ?? 1, 1);
  switch (rule.frequency) {
    case 'daily': return addDays(key, 1);
    case 'weekdays': {
      let next = addDays(key, 1);
      while ([0, 6].includes(fromKey(next).getUTCDay())) next = addDays(next, 1);
      return next;
    }
    case 'weekly': return addDays(key, 7);
    case 'monthly': return addMonths(key, 1);
    case 'yearly': return addMonths(key, 12);
    case 'custom': return rule.unit === 'week' ? addDays(key, 7 * n) : rule.unit === 'month' ? addMonths(key, n) : addDays(key, n);
  }
}

export const daysBetween = (a: string, b: string) => Math.round((fromKey(b).getTime() - fromKey(a).getTime()) / 86_400_000);

/** "2026-10-30T08:00" moved by `days`. */
export function shiftReminder(remindAt: string | undefined, days: number): string | undefined {
  if (!remindAt || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(remindAt)) return undefined;
  return `${addDays(remindAt.slice(0, 10), days)}${remindAt.slice(10)}`;
}
