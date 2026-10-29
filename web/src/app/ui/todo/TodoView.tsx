import { useMemo, useRef, useState } from 'react';
import { sameId } from '../../lib/bytes.ts';
import { addDays, todayKey } from '../../lib/days.ts';
import { CategoryChips, Empty } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { TaskRow } from './TaskRow.tsx';

/**
 * To-do (SPEC §6.7). Ticking fills, checks and strikes the task, which stays 1.2 s before it
 * moves to Completed (tap again to cancel), with a 4 s Undo. Unticking in Completed is instant.
 */
export default function TodoView() {
  const { store, toast, navigate } = useDiary();
  const [category, setCategory] = useState<string | null>(null);
  const [showDone, setShowDone] = useState(() => { try { return localStorage.getItem('folio.showCompleted') !== 'no'; } catch { return true; } });
  const [ticking, setTicking] = useState<Set<string>>(new Set());
  const timers = useRef(new Map<string, ReturnType<typeof setTimeout>>());
  const [text, setText] = useState('');
  const today = todayKey();

  const all = useMemo(() => store.tasks().filter((t) => !category || sameId(t.data.categoryID, category)), [store.revision, category]);
  const active = all.filter((t) => !t.data.isCompleted).sort((a, b) => {
    const rank = (t: typeof a) => (t.data.dayKey ? (t.data.dayKey < today ? 0 : 1) : 2);
    return rank(a) - rank(b) || (a.data.dayKey ?? '').localeCompare(b.data.dayKey ?? '') || (a.data.minutesFromMidnight ?? -1) - (b.data.minutesFromMidnight ?? -1) || a.data.sortIndex - b.data.sortIndex;
  });
  const done = all.filter((t) => t.data.isCompleted).sort((a, b) => (b.data.completedAt ?? 0) - (a.data.completedAt ?? 0));

  function tick(id: string) {
    const running = timers.current.get(id);
    if (running) {
      clearTimeout(running);
      timers.current.delete(id);
      setTicking((s) => { const n = new Set(s); n.delete(id); return n; });
      return;
    }
    setTicking((s) => new Set(s).add(id));
    timers.current.set(id, setTimeout(() => {
      timers.current.delete(id);
      setTicking((s) => { const n = new Set(s); n.delete(id); return n; });
      store.put('task', { isCompleted: true, completedAt: Date.now() }, id);
      toast('Done', { label: 'Undo', run: () => store.put('task', { isCompleted: false, completedAt: undefined }, id) });
    }, 1200));
  }

  /** Quick add: "today" / "tomorrow" in the text sets the date (SPEC §6.7). */
  function quickAdd(event: React.FormEvent) {
    event.preventDefault();
    let title = text.trim();
    if (!title) return;
    let dayKey: string | undefined;
    const match = /\b(today|tomorrow)\b/i.exec(title);
    if (match) {
      dayKey = match[1]!.toLowerCase() === 'today' ? today : addDays(today, 1);
      title = title.replace(match[0], '').replace(/\s{2,}/g, ' ').trim() || title;
    }
    const sortIndex = Math.max(-1, ...store.tasks().map((t) => t.data.sortIndex)) + 1;
    store.put('task', { title: title.slice(0, 200), dayKey, isCompleted: false, sortIndex, createdAt: Date.now(), categoryID: category ?? undefined });
    setText('');
  }

  const trashCount = store.trashed().tasks.length;
  return (
    <div className="scroll">
      <div className="page">
        <div className="page-title"><h1 className="title1">To-do</h1></div>
        <CategoryChips selected={category} onSelect={setCategory} />
        <div style={{ marginTop: 12 }}>
          {active.length === 0 ? <Empty icon="seal" text="All clear." /> : active.map((t, i) => (
            <TaskRow key={t.id} task={t} checked={ticking.has(t.id)} showDate menu style={{ animationDelay: `${i * 30}ms` }} onToggle={() => tick(t.id)} />
          ))}
        </div>
        {done.length > 0 && (
          <section style={{ marginTop: 18 }}>
            <button className="text-btn" aria-expanded={showDone} onClick={() => { setShowDone(!showDone); try { localStorage.setItem('folio.showCompleted', showDone ? 'no' : 'yes'); } catch { /* */ } }}
              style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 600 }}>
              Completed · {done.length}<Icon name={showDone ? 'chevronDown' : 'chevronRight'} small />
            </button>
            {showDone && done.map((t) => (
              <TaskRow key={t.id} task={t} showDate menu onToggle={() => store.put('task', { isCompleted: false, completedAt: undefined }, t.id)} />
            ))}
          </section>
        )}
        {trashCount > 0 && <p style={{ textAlign: 'center', marginTop: 24 }}><button className="link" onClick={() => navigate('/app/profile/deleted')}>Recently Deleted · {trashCount}</button></p>}
        <form className="quick-add glass" onSubmit={quickAdd}>
          <label className="sr-only" htmlFor="quick-add">Add a task</label>
          <input id="quick-add" placeholder="Add a task…" value={text} maxLength={200} onChange={(e) => setText(e.target.value)} />
          <button className="icon-btn ember" aria-label="Add task" disabled={!text.trim()}><Icon name="plus" /></button>
        </form>
      </div>
    </div>
  );
}
