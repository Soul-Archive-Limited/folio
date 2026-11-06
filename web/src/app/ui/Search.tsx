import { useDeferredValue, useMemo, useState } from 'react';
import { addDays, formatShort, todayKey } from '../lib/days.ts';
import { highlight, search, type SearchDoc, type SearchFilters, snippet, words } from '../lib/search.ts';
import { CategoryChip, Empty, PhotoImg, Sheet, useCloseSheet } from './common.tsx';
import { useDiary } from './context.tsx';
import { Icon } from './Icons.tsx';

/** Search (Batch J): the diary already decrypted in this tab, searched in memory. */
export default function Search({ tasksOnly, onClose }: { tasksOnly: boolean; onClose: () => void }) {
  return (
    <Sheet label="Search" onClose={onClose} wide scrim tall>
      <SearchBody tasksOnly={tasksOnly} />
    </Sheet>
  );
}

type Range = 'any' | 'month' | 'quarter' | 'year' | 'lastYear';

function rangeOf(range: Range): Pick<SearchFilters, 'from' | 'through'> {
  const today = todayKey();
  const year = Number(today.slice(0, 4));
  switch (range) {
    case 'month': return { from: today.slice(0, 8) + '01', through: today };
    case 'quarter': return { from: addDays(today, -91), through: today };
    case 'year': return { from: `${year}-01-01`, through: today };
    case 'lastYear': return { from: `${year - 1}-01-01`, through: `${year - 1}-12-31` };
    default: return {};
  }
}

function SearchBody({ tasksOnly: initialTasksOnly }: { tasksOnly: boolean }) {
  const { store, openEntry, openTask } = useDiary();
  const close = useCloseSheet();
  const [text, setText] = useState('');
  const [category, setCategory] = useState('');
  const [hasPhotos, setHasPhotos] = useState(false);
  const [range, setRange] = useState<Range>('any');
  const [status, setStatus] = useState<'any' | 'open' | 'done'>('any');
  const [tasksOnly, setTasksOnly] = useState(initialTasksOnly);
  const query = useDeferredValue(text);
  const filters: SearchFilters = { tasksOnly, categories: category ? [category] : [], hasPhotos, status, ...rangeOf(range) };
  const results = useMemo(() => search(store, query, filters), [store.revision, query, tasksOnly, category, hasPhotos, range, status]);
  const terms = useMemo(() => [...new Set(words(query))], [query]);
  const entries = results.filter((d) => d.kind === 'entry');
  const tasks = results.filter((d) => d.kind === 'task');
  const active = !!query.trim() || !!category || hasPhotos || range !== 'any' || status !== 'any';

  const open = (doc: SearchDoc) => {
    close();
    if (doc.kind === 'entry') openEntry(doc.id); else openTask({ taskId: doc.id });
  };

  return (
    <div className="sheet-body search">
      <label className="search-field">
        <Icon name="search" small />
        <input className="field" type="search" placeholder={tasksOnly ? 'Search tasks' : 'Search your diary'} value={text}
          onChange={(e) => setText(e.target.value)} autoFocus aria-label="Search" enterKeyHint="search" />
      </label>
      <div className="chips search-filters" role="group" aria-label="Filters">
        <select className="chip" value={category} onChange={(e) => setCategory(e.target.value)} aria-label="Category">
          <option value="">Any category</option>
          {store.categories().map((c) => <option key={c.id} value={c.id}>{c.data.name}</option>)}
        </select>
        {!tasksOnly && <button className="chip" aria-pressed={hasPhotos} onClick={() => setHasPhotos(!hasPhotos)}><Icon name="photo" small />Photos</button>}
        <select className="chip" value={range} onChange={(e) => setRange(e.target.value as Range)} aria-label="Dates">
          <option value="any">Any time</option>
          <option value="month">This month</option>
          <option value="quarter">Past 3 months</option>
          <option value="year">This year</option>
          <option value="lastYear">Last year</option>
        </select>
        <select className="chip" value={status} onChange={(e) => setStatus(e.target.value as typeof status)} aria-label="Tasks">
          <option value="any">Open or done</option>
          <option value="open">Open tasks</option>
          <option value="done">Done tasks</option>
        </select>
        <button className="chip" aria-pressed={tasksOnly} onClick={() => setTasksOnly(!tasksOnly)}>Tasks only</button>
      </div>
      {!active ? (
        <Empty icon="search" text="Search titles, pages, categories and tasks. It runs in this tab only." />
      ) : !results.length ? (
        <Empty icon="search" text={query.trim() ? `No matches for “${query.trim()}”.` : 'Nothing matches these filters.'} />
      ) : (
        <div className="search-results" aria-live="polite">
          {entries.length > 0 && <h2 className="section-label">Pages · {entries.length}</h2>}
          {entries.slice(0, 300).map((d) => (
            <button key={d.id} className="card" onClick={() => open(d)}>
              {d.firstPhotoID && <span className="thumb"><PhotoImg id={d.firstPhotoID} rendition="thumb" /></span>}
              <span className="grow" style={{ minWidth: 0, textAlign: 'start' }}>
                <span className="ink2" style={{ display: 'block', fontSize: 12 }}>{d.dayKey ? formatShort(d.dayKey) + ' ' + d.dayKey.slice(0, 4) : ''}</span>
                <span className="t"><Marked text={d.title || 'Untitled'} terms={terms} /></span>
                {d.text && <span className="p"><Marked text={snippet(d.text, terms)} terms={terms} /></span>}
                {d.categoryID && <span className="meta"><CategoryChip id={d.categoryID} /></span>}
              </span>
            </button>
          ))}
          {tasks.length > 0 && <h2 className="section-label">Tasks · {tasks.length}</h2>}
          {tasks.slice(0, 300).map((d) => (
            <button key={d.id} className="card" onClick={() => open(d)}>
              <span aria-label={d.isCompleted ? 'Done' : 'Open'}><Icon name={d.isCompleted ? 'check' : 'todo'} /></span>
              <span className="grow" style={{ minWidth: 0, textAlign: 'start' }}>
                <span className="t" style={{ textDecoration: d.isCompleted ? 'line-through' : undefined }}><Marked text={d.title} terms={terms} /></span>
                {d.subtasks.filter((s) => highlight(s, terms).some((p) => p.match)).slice(0, 3).map((s) => (
                  <span key={s} className="p">↳ <Marked text={s} terms={terms} /></span>
                ))}
                <span className="meta">
                  {d.dayKey && <span className="ink2" style={{ fontSize: 12 }}>{formatShort(d.dayKey)}</span>}
                  {d.categoryID && <CategoryChip id={d.categoryID} />}
                </span>
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function Marked({ text, terms }: { text: string; terms: string[] }) {
  return <>{highlight(text, terms).map((p, i) => (p.match ? <mark key={i}>{p.text}</mark> : <span key={i}>{p.text}</span>))}</>;
}
