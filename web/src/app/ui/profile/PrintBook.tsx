import { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import { formatTime, parseDayKey, todayKey } from '../../lib/days.ts';
import { byTimeInDay } from '../../lib/markers.ts';
import { photoURL } from '../../lib/photos.ts';
import type { EntryData, TaskData } from '../../lib/payloads.ts';
import type { Rec } from '../../lib/store.ts';
import { Avatar } from '../Avatar.tsx';
import { Sheet } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { moodOf } from '../Mood.tsx';
import { cleanPlace, placeLine } from '../../lib/place.ts';
import { Prose } from '../Prose.tsx';

type Range = { from: string; until: string };
const fmt = (o: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('en-GB', o);

/**
 * Export PDF on the web (Batch L): the iPhone's book (SPEC §6.21) laid out as an A5 print page
 * and handed to the browser's own print dialog, where "Save as PDF" makes the file. It's built
 * in this tab from the diary already decrypted here; nothing is uploaded.
 */
export default function PrintBook({ onClose }: { onClose: () => void }) {
  const { store } = useDiary();
  const days = useMemo(() => store.entries().map((e) => e.data.dayKey).sort(), [store.revision]);
  const year = todayKey().slice(0, 4);
  const [range, setRange] = useState<Range>({ from: days[0] ?? `${year}-01-01`, until: todayKey() });
  const [photos, setPhotos] = useState(true);
  const [tasks, setTasks] = useState(true);
  const [printing, setPrinting] = useState(false);
  const quick: [string, Range][] = [
    ['This year', { from: `${year}-01-01`, until: `${year}-12-31` }],
    ['Last year', { from: `${Number(year) - 1}-01-01`, until: `${Number(year) - 1}-12-31` }],
    ['Last 3 years', { from: `${Number(year) - 2}-01-01`, until: todayKey() }],
    ['Everything', { from: days[0] ?? `${year}-01-01`, until: days[days.length - 1] ?? todayKey() }],
  ];
  const count = days.filter((d) => d >= range.from && d <= range.until).length;

  return (
    <Sheet label="Export PDF" onClose={onClose} scrim>
      <h2 className="title2" style={{ marginTop: 0 }}>Export PDF</h2>
      <p className="callout ink2">A book of your pages, made in this browser. Your browser's print window opens — choose “Save as PDF”.</p>
      <div className="chips" style={{ margin: '12px 0' }}>
        {quick.map(([label, r]) => <button key={label} className="chip" aria-pressed={r.from === range.from && r.until === range.until} onClick={() => setRange(r)}>{label}</button>)}
      </div>
      <div className="group glass">
        <label className="row"><span className="grow">From</span><input type="date" value={range.from} max={range.until} onChange={(e) => e.target.value && setRange({ ...range, from: e.target.value })} /></label>
        <label className="row"><span className="grow">Until</span><input type="date" value={range.until} min={range.from} onChange={(e) => e.target.value && setRange({ ...range, until: e.target.value })} /></label>
        <label className="row"><span className="grow">Photos</span><input type="checkbox" className="toggle" checked={photos} onChange={(e) => setPhotos(e.target.checked)} /></label>
        <label className="row"><span className="grow">Tasks</span><input type="checkbox" className="toggle" checked={tasks} onChange={(e) => setTasks(e.target.checked)} /></label>
      </div>
      <button className="btn primary wide" style={{ marginTop: 16 }} disabled={count === 0 || printing} onClick={() => setPrinting(true)}>
        {printing ? 'Preparing…' : count === 0 ? 'No pages in these dates' : `Create PDF · ${count} ${count === 1 ? 'page' : 'pages'}`}
      </button>
      {printing && <Book range={range} photos={photos} tasks={tasks} onDone={() => setPrinting(false)} />}
    </Sheet>
  );
}

function Book({ range, photos, tasks, onDone }: { range: Range; photos: boolean; tasks: boolean; onDone: () => void }) {
  const { store, key } = useDiary();
  const entries = store.entries().filter((e) => e.data.dayKey >= range.from && e.data.dayKey <= range.until)
    .sort((a, b) => a.data.dayKey.localeCompare(b.data.dayKey) || byTimeInDay(a, b));
  const months = new Map<string, Rec<EntryData>[]>();
  for (const e of entries) months.set(e.data.dayKey.slice(0, 7), [...(months.get(e.data.dayKey.slice(0, 7)) ?? []), e]);
  const tasksByDay = new Map<string, Rec<TaskData>[]>();
  if (tasks) for (const t of store.tasks()) if (t.data.dayKey) tasksByDay.set(t.data.dayKey, [...(tasksByDay.get(t.data.dayKey) ?? []), t]);
  const [urls, setUrls] = useState<Record<string, string> | null>(photos ? null : {});
  const name = store.settings?.displayName?.trim();

  useEffect(() => {
    if (!photos) return;
    let live = true;
    const ids = entries.flatMap((e) => store.photosOf(e.id).map((p) => p.id));
    void Promise.all(ids.map(async (id) => [id, await photoURL(key, store.userId, id, 'display')] as const)).then((pairs) => {
      if (live) setUrls(Object.fromEntries(pairs.filter(([, u]) => u)) as Record<string, string>);
    });
    return () => { live = false; };
  }, []);

  useEffect(() => {
    if (!urls) return;
    const images = [...document.querySelectorAll<HTMLImageElement>('.print-book img')];
    void Promise.all(images.map((img) => img.decode().catch(() => undefined))).then(() => {
      const after = () => { window.removeEventListener('afterprint', after); onDone(); };
      window.addEventListener('afterprint', after);
      window.print();
    });
  }, [urls]);

  if (!urls) return null;
  const rangeText = `${fmt({ day: 'numeric', month: 'long', year: 'numeric' }).format(parseDayKey(range.from))} – ${fmt({ day: 'numeric', month: 'long', year: 'numeric' }).format(parseDayKey(range.until))}`;
  return createPortal(
    <div className="print-book" aria-hidden="true">
      <section className="pb-cover">
        <Avatar settings={store.settings} fallback={name || 'F'} big />
        <h1>{name ? `${name}’s diary` : 'My diary'}</h1>
        <p className="pb-range">{rangeText}</p>
        <p className="pb-count">{entries.length} {entries.length === 1 ? 'page' : 'pages'}</p>
        <p className="pb-word">Folio</p>
      </section>
      {[...months].map(([month, list]) => (
        <section key={month} className="pb-month">
          <header>
            <h2>{fmt({ month: 'long' }).format(parseDayKey(`${month}-01`))} <em>{month.slice(0, 4)}</em></h2>
            <p>{list.length} {list.length === 1 ? 'PAGE' : 'PAGES'}</p>
          </header>
          {list.map((e, i) => {
            const mood = moodOf(e.data.mood);
            const sameDayNext = list[i + 1]?.data.dayKey === e.data.dayKey;
            const dayTasks = !sameDayNext ? tasksByDay.get(e.data.dayKey) ?? [] : [];
            return (
              <article key={e.id}>
                <p className="pb-date">{[fmt({ weekday: 'long', day: 'numeric', month: 'long' }).format(parseDayKey(e.data.dayKey)),
                  e.data.minutesFromMidnight !== undefined ? formatTime(e.data.minutesFromMidnight) : '', mood?.title ?? ''].filter(Boolean).join(' · ')}</p>
                {e.data.title && <h3>{e.data.title}</h3>}
                {cleanPlace(e.data.place) && <p className="pb-place">{placeLine(cleanPlace(e.data.place)!)}</p>}
                <Prose markdown={e.data.bodyMarkdown} />
                {store.photosOf(e.id).map((p) => urls[p.id] && <img key={p.id} src={urls[p.id]} alt="" />)}
                {dayTasks.length > 0 && (
                  <div className="pb-tasks"><p>TASKS</p>
                    {dayTasks.map((t) => <p key={t.id} className={t.data.isCompleted ? 'done' : ''}>{t.data.isCompleted ? '☑' : '☐'} {t.data.title}</p>)}
                  </div>
                )}
                {!sameDayNext && <p className="pb-sep">·  ·  ·</p>}
              </article>
            );
          })}
        </section>
      ))}
    </div>,
    document.body,
  );
}
