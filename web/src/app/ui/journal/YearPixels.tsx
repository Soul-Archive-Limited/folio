import { useMemo, useState } from 'react';
import { todayKey } from '../../lib/days.ts';
import { categoryColor } from '../../lib/payloads.ts';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { MOODS, moodOf } from '../Mood.tsx';

const pad = (n: number) => String(n).padStart(2, '0');
const monthLetters = Array.from({ length: 12 }, (_, m) => new Intl.DateTimeFormat(undefined, { month: 'narrow' }).format(new Date(2026, m, 1)));

/** Year in Pixels (Batch J): every day a square, by mood or category; ‹ › for years; no streaks. */
export function YearPixels() {
  const { store, openEntry, showDay } = useDiary();
  const today = todayKey();
  const thisYear = Number(today.slice(0, 4));
  const firstYear = useMemo(() => Math.min(thisYear, ...store.entries().map((e) => Number(e.data.dayKey.slice(0, 4)))), [store.revision]);
  const [year, setYear] = useState(thisYear);
  const [byMood, setByMood] = useState(true);
  const days = useMemo(() => {
    const map = new Map<string, { ids: string[]; mood?: number; category?: string }>();
    for (const e of store.entries().filter((x) => x.data.dayKey.startsWith(`${year}-`)).sort((a, b) => (a.data.minutesFromMidnight ?? 1e9) - (b.data.minutesFromMidnight ?? 1e9) || a.data.createdAt - b.data.createdAt)) {
      const d = map.get(e.data.dayKey) ?? { ids: [] };
      d.ids.push(e.id);
      if (moodOf(e.data.mood)) d.mood = e.data.mood;
      d.category ??= e.data.categoryID;
      map.set(e.data.dayKey, d);
    }
    return map;
  }, [store.revision, year]);

  return (
    <section className="pixels" aria-label={`Year in Pixels, ${year}`}>
      <div className="pixels-head">
        <button className="icon-btn" aria-label="Previous year" disabled={year <= firstYear} onClick={() => setYear(year - 1)}><Icon name="chevronLeft" /></button>
        <h2 className="title1" style={{ fontVariantNumeric: 'tabular-nums' }}>{year}</h2>
        <button className="icon-btn" aria-label="Next year" disabled={year >= thisYear} onClick={() => setYear(year + 1)}><Icon name="chevronRight" /></button>
        <div className="segmented glass" role="group" aria-label="Colour by" style={{ marginLeft: 'auto' }}>
          <button aria-pressed={byMood} onClick={() => setByMood(true)}>Mood</button>
          <button aria-pressed={!byMood} onClick={() => setByMood(false)}>Category</button>
        </div>
      </div>
      <div className="pixel-grid" role="grid">
        <span />
        {monthLetters.map((l, i) => <span key={i} className="caption ink3 pixel-month">{l}</span>)}
        {Array.from({ length: 31 }, (_, r) => r + 1).flatMap((dayNumber) => [
          <span key={`l${dayNumber}`} className="pixel-day">{dayNumber === 1 || dayNumber % 5 === 0 ? dayNumber : ''}</span>,
          ...Array.from({ length: 12 }, (_, m) => {
            const key = `${year}-${pad(m + 1)}-${pad(dayNumber)}`;
            const valid = new Date(Date.UTC(year, m, dayNumber)).getUTCDate() === dayNumber;
            if (!valid) return <span key={key} />;
            const d = days.get(key);
            const mood = moodOf(d?.mood);
            const background = !d ? undefined : byMood ? (mood?.color ?? undefined) : d.category ? categoryColor(store.get('category', d.category)?.data.colorKey) : undefined;
            const opacity = d && byMood && mood ? mood.opacity : 1;
            return (
              <button key={key} className={`pixel${d ? ' written' : ''}${key > today ? ' future' : ''}${key === today ? ' today' : ''}`}
                disabled={!d} aria-label={`${key}${d ? `, ${d.ids.length === 1 ? '1 page' : `${d.ids.length} pages`}${mood ? `, ${mood.title}` : ''}` : ', nothing written'}`}
                style={background ? { background, opacity } : undefined}
                onClick={() => d && (d.ids.length === 1 ? openEntry(d.ids[0]!) : showDay(key))} />
            );
          }),
        ])}
      </div>
      <div className="pixel-legend caption ink2">
        {byMood ? MOODS.map((m) => <span key={m.value}><i style={{ background: m.color, opacity: m.opacity }} />{m.title}</span>)
          : store.categories().map((c) => <span key={c.id}><i style={{ background: categoryColor(c.data.colorKey) }} />{c.data.name}</span>)}
        <span><i className="none" />{byMood ? 'No mood' : 'No category'}</span>
      </div>
    </section>
  );
}
