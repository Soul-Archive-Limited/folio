/**
 * Quick add's natural dates and times (SPEC §6.7), the same rules as the iPhone's
 * `QuickAddParser.swift` (Batch L brings them to the web): "Call Mum tomorrow 6pm" is "Call Mum",
 * tomorrow at 18:00. Phrases count only at the start or end of the line, so "Today's papers"
 * stays as typed, and the whole line is never eaten ("Tomorrow" alone is a task called that).
 */
import { addDays, pad } from './days.ts';

export interface QuickAdd { title: string; dayKey?: string; minutesFromMidnight?: number }
interface TimeMatch { candidates: number[]; preferred: number }
interface DayMatch { day: string; time?: TimeMatch }

const WEEKDAYS = '(mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)';
const MONTHS = '(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
const COUNT = '(\\d{1,3}|a|an|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)';
const WORDS: Record<string, number> = { a: 1, an: 1, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12 };

type DayKind = 'dayAfterTomorrow' | 'todayOrTonight' | 'tomorrow' | 'relative' | 'nextWeekOrMonth' | 'weekend' | 'weekday' | 'dayMonth' | 'monthDay' | 'numeric';
type TimeKind = 'clock' | 'clock24' | 'bareHour' | 'partOfDay';

const DAY_PATTERNS: [DayKind, string][] = [
  ['dayAfterTomorrow', 'day after tomorrow'],
  ['todayOrTonight', '(today|tonight)'],
  ['tomorrow', '(?:tomorrow|tmrw|tmr)'],
  ['relative', `(?:in|after) ${COUNT} (days?|weeks?|months?)`],
  ['nextWeekOrMonth', 'next (week|month)'],
  ['weekend', '(?:this )?weekend'],
  ['weekday', '(?:on )?(?:(next|this) )?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)'],
  ['weekday', `(?:on |(next|this) )${WEEKDAYS}`],
  ['dayMonth', `(?:on )?(?:the )?(\\d{1,2})(?:st|nd|rd|th)?(?: of)? ${MONTHS},?(?: (\\d{4}))?`],
  ['monthDay', `(?:on )?${MONTHS} (\\d{1,2})(?:st|nd|rd|th)?,?(?: (\\d{4}))?`],
  ['numeric', '(?:on )?(\\d{1,2})[/-](\\d{1,2})(?:[/-](\\d{2}|\\d{4}))?'],
  ['numeric', '(?:on )?(\\d{1,2})\\.(\\d{1,2})\\.(\\d{2}|\\d{4})'],
];
const TIME_PATTERNS: [TimeKind, string][] = [
  ['clock', '(?:at )?(\\d{1,2})(?:[:.](\\d{2}))? ?(am|pm|a\\.m\\.|p\\.m\\.)'],
  ['clock24', '(?:at )?(\\d{1,2})[:.](\\d{2})'],
  ['bareHour', 'at (\\d{1,2})'],
  ['partOfDay', '(?:at |in the |this )?(noon|midday|morning|afternoon|evening)'],
];

const ymd = (key: string) => key.split('-').map(Number) as [number, number, number];
const weekdayOf = (key: string) => { const [y, m, d] = ymd(key); return new Date(Date.UTC(y, m - 1, d)).getUTCDay() + 1; }; // 1 = Sunday
const daysIn = (y: number, m: number) => new Date(Date.UTC(y, m, 0)).getUTCDate();
const keyOf = (y: number, m: number, d: number) => `${y}-${pad(m)}-${pad(d)}`;
const validDate = (y: number, m: number, d: number) => m >= 1 && m <= 12 && d >= 1 && d <= daysIn(y, m);

function addMonthsTo(key: string, n: number): string {
  const [y, m, d] = ymd(key);
  const total = y * 12 + (m - 1) + n;
  const year = Math.floor(total / 12), month = (total % 12) + 1;
  return keyOf(year, month, Math.min(d, daysIn(year, month)));
}

function dated(day: number, month: number, year: number | undefined, today: string): string | undefined {
  if (month < 1 || month > 12 || day < 1 || day > 31) return undefined;
  if (year !== undefined) return validDate(year, month, day) ? keyOf(year, month, day) : undefined;
  const thisYear = ymd(today)[0];
  for (const y of [thisYear, thisYear + 1]) {
    if (validDate(y, month, day) && keyOf(y, month, day) >= today) return keyOf(y, month, day);
  }
  return undefined;
}

const indexOfPrefix = (list: string[], name: string) => list.findIndex((p) => name.startsWith(p));

function readDay(kind: DayKind, g: (string | undefined)[], today: string, monthFirst: boolean): DayMatch | undefined {
  switch (kind) {
    case 'dayAfterTomorrow': return { day: addDays(today, 2) };
    case 'todayOrTonight': return g[0] === 'tonight' ? { day: today, time: { candidates: [1200], preferred: 1200 } } : { day: today };
    case 'tomorrow': return { day: addDays(today, 1) };
    case 'relative': {
      const n = g[0] ? (Number.isNaN(Number(g[0])) ? WORDS[g[0]] : Number(g[0])) : undefined;
      if (!n || n <= 0 || n > 400 || !g[1]) return undefined;
      if (g[1].startsWith('day')) return { day: addDays(today, n) };
      if (g[1].startsWith('week')) return { day: addDays(today, 7 * n) };
      return { day: addMonthsTo(today, n) };
    }
    case 'nextWeekOrMonth': return { day: g[0] === 'week' ? addDays(today, 7) : addMonthsTo(today, 1) };
    case 'weekend': {
      const wd = weekdayOf(today);
      return { day: wd === 7 || wd === 1 ? today : addDays(today, 7 - wd) };
    }
    case 'weekday': {
      const index = g[1] ? indexOfPrefix(['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'], g[1]) : -1;
      if (index < 0) return undefined;
      let ahead = (index + 1 - weekdayOf(today) + 7) % 7;
      if (g[0] === 'next' && ahead === 0) ahead = 7;
      return { day: addDays(today, ahead) };
    }
    case 'dayMonth':
    case 'monthDay': {
      const [dayText, monthText] = kind === 'dayMonth' ? [g[0], g[1]] : [g[1], g[0]];
      const month = monthText ? indexOfPrefix(['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'], monthText) + 1 : 0;
      if (!dayText || !month) return undefined;
      const day = dated(Number(dayText), month, g[2] ? Number(g[2]) : undefined, today);
      return day ? { day } : undefined;
    }
    case 'numeric': {
      if (!g[0] || !g[1]) return undefined;
      const [a, b] = [Number(g[0]), Number(g[1])];
      const [d, m] = monthFirst ? [b, a] : [a, b];
      let year = g[2] ? Number(g[2]) : undefined;
      if (year !== undefined && year < 100) year += 2000;
      const day = dated(d, m, year, today);
      return day ? { day } : undefined;
    }
  }
}

function readTime(kind: TimeKind, g: (string | undefined)[]): TimeMatch | undefined {
  const fixed = (minutes: number): TimeMatch => ({ candidates: [minutes], preferred: minutes });
  switch (kind) {
    case 'partOfDay':
      return fixed(g[0] === 'noon' || g[0] === 'midday' ? 720 : g[0] === 'morning' ? 540 : g[0] === 'afternoon' ? 900 : 1080);
    case 'clock': {
      const hour = Number(g[0]), minute = g[1] ? Number(g[1]) : 0;
      if (!(hour >= 1 && hour <= 12) || minute > 59) return undefined;
      return fixed(((hour % 12) + ((g[2] ?? '').startsWith('p') ? 12 : 0)) * 60 + minute);
    }
    case 'clock24':
    case 'bareHour': {
      const hour = Number(g[0]), minute = kind === 'clock24' && g[1] ? Number(g[1]) : 0;
      if (!(hour >= 0 && hour <= 23) || minute > 59) return undefined;
      if (hour === 0 || hour >= 12) return fixed(hour * 60 + minute);
      const morning = hour * 60 + minute, evening = (hour + 12) * 60 + minute;
      return { candidates: [morning, evening], preferred: hour <= 6 ? evening : morning };
    }
  }
}

function firstMatch<K, T>(patterns: [K, string][], text: string, atEnd: boolean, read: (kind: K, groups: (string | undefined)[]) => T | undefined) {
  for (const [kind, pattern] of patterns) {
    const re = new RegExp(atEnd ? `(?:^|(?<=[\\s,]))(?:${pattern})[.!]?$` : `^(?:${pattern})(?=$|[\\s,])`, 'i');
    const match = re.exec(text);
    if (!match) continue;
    const value = read(kind, match.slice(1).map((v) => v?.toLowerCase()));
    if (value !== undefined) return { start: match.index, end: match.index + match[0].length, value };
  }
  return undefined;
}

/** `today` is a day key, `minutesNow` the clock; `monthFirst` reads 5/11 as 11 May (US). */
export function parseQuickAdd(text: string, today: string, minutesNow: number, monthFirst = false): QuickAdd {
  let rest = text.trim();
  let day: string | undefined;
  let time: TimeMatch | undefined;
  for (let round = 0; round < 3; round++) {
    let peeled: { remaining: string; day?: string; time?: TimeMatch } | undefined;
    for (const atEnd of [true, false]) {
      const t = time ? undefined : firstMatch(TIME_PATTERNS, rest, atEnd, readTime);
      if (t) { peeled = { remaining: rest.slice(0, t.start) + ' ' + rest.slice(t.end), time: t.value }; break; }
      const d = day ? undefined : firstMatch(DAY_PATTERNS, rest, atEnd, (k, g) => readDay(k, g, today, monthFirst));
      if (d) { peeled = { remaining: rest.slice(0, d.start) + ' ' + rest.slice(d.end), day: d.value.day, time: d.value.time }; break; }
    }
    if (!peeled) break;
    const remaining = peeled.remaining.replace(/^[\s,]+|[\s,]+$/g, '').replace(/\s{2,}/g, ' ');
    if (!remaining) break;
    rest = remaining;
    if (peeled.day) day = peeled.day;
    if (peeled.time) time = peeled.time;
  }
  if (!day && !time) return { title: rest };
  let resolved = day ?? today;
  let minutes: number | undefined;
  if (time) {
    if (resolved === today) {
      const future = time.candidates.find((c) => c > minutesNow);
      if (future !== undefined) minutes = future;
      else {
        minutes = time.candidates[0];
        if (!day) resolved = addDays(today, 1);
      }
    } else minutes = time.preferred;
  }
  return { title: rest, dayKey: resolved, minutesFromMidnight: minutes };
}
