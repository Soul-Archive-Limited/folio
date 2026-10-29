/**
 * Floating diary days (SPEC §5): a day is the string "YYYY-MM-DD" and never moves with the
 * time zone. Display is en-GB, like the app.
 */

export const pad = (n: number) => String(n).padStart(2, '0');
export const dayKeyOf = (date: Date) => `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
export const todayKey = () => dayKeyOf(new Date());

export function parseDayKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y!, (m ?? 1) - 1, d ?? 1, 12);
}

export const addDays = (key: string, days: number) => {
  const date = parseDayKey(key);
  date.setDate(date.getDate() + days);
  return dayKeyOf(date);
};

export interface Month { year: number; month: number } // month 0–11
export const monthOf = (key: string): Month => ({ year: Number(key.slice(0, 4)), month: Number(key.slice(5, 7)) - 1 });
export const monthKey = (m: Month) => `${m.year}-${pad(m.month + 1)}`;
export const addMonths = (m: Month, n: number): Month => {
  const total = m.year * 12 + m.month + n;
  return { year: Math.floor(total / 12), month: ((total % 12) + 12) % 12 };
};

/** Six weeks of day keys starting on the first weekday (1 = Sunday … 7 = Saturday, like Calendar). */
export function monthGrid(m: Month, firstWeekday: number): string[] {
  const first = new Date(m.year, m.month, 1, 12);
  const offset = (first.getDay() - (firstWeekday - 1) + 7) % 7;
  const start = new Date(m.year, m.month, 1 - offset, 12);
  return Array.from({ length: 42 }, (_, i) => dayKeyOf(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i, 12)));
}

/** The locale's first weekday (Monday in the UK), in Calendar numbering. */
export function localeFirstWeekday(): number {
  try {
    const info = (new Intl.Locale(navigator.language) as Intl.Locale & { getWeekInfo?: () => { firstDay: number }; weekInfo?: { firstDay: number } });
    const firstDay = info.getWeekInfo?.().firstDay ?? info.weekInfo?.firstDay;
    if (firstDay) return (firstDay % 7) + 1;
  } catch { /* older browsers */ }
  return 2;
}

const fmt = (options: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('en-GB', options);
export const formatLong = (key: string) => fmt({ weekday: 'long', day: 'numeric', month: 'long' }).format(parseDayKey(key));
export const formatLongYear = (key: string) => fmt({ weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(parseDayKey(key));
export const formatShort = (key: string) => fmt({ weekday: 'short', day: 'numeric', month: 'short' }).format(parseDayKey(key));
export const formatDayMonth = (key: string) => fmt({ day: 'numeric', month: 'short' }).format(parseDayKey(key));
export const monthName = (m: Month) => fmt({ month: 'long' }).format(new Date(m.year, m.month, 1, 12));
export const weekdayNames = (firstWeekday: number) =>
  Array.from({ length: 7 }, (_, i) => fmt({ weekday: 'short' }).format(new Date(2024, 0, 7 + ((firstWeekday - 1 + i) % 7), 12)));
export const formatTime = (minutes: number) => `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
export const formatMonthYear = (key: string) => fmt({ month: 'long', year: 'numeric' }).format(parseDayKey(key));
