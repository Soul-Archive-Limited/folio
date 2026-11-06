import { useMemo, useRef, useState } from 'react';
import { sameId } from '../../lib/bytes.ts';
import { addDays, formatShort, formatTime, todayKey } from '../../lib/days.ts';
import { parseQuickAdd } from '../../lib/quickadd.ts';
import { groupTasks } from '../../lib/task-groups.ts';
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
  const groups = groupTasks(active, today);
  const [closed, setClosed] = useState<Set<string>>(() => { try { return new Set(JSON.parse(localStorage.getItem('folio.todoClosed') ?? '[]')); } catch { return new Set(); } });
  const toggleGroup = (id: string) => setClosed((now) => {
    const next = new Set(now);
    if (next.has(id)) next.delete(id); else next.add(id);
    try { localStorage.setItem('folio.todoClosed', JSON.stringify([...next])); } catch { /* private mode */ }
    return next;
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
      store.setTaskDone(id, true);
      toast('Done', { label: 'Undo', run: () => store.put('task', { isCompleted: false, completedAt: undefined }, id) });
    }, 1200));
  }

  /** Quick add (SPEC §6.7): natural dates and times at the start or end, as on the iPhone. */
  const minutesNow = () => { const d = new Date(); return d.getHours() * 60 + d.getMinutes(); };
  const monthFirst = /-US$/.test(navigator.language);
  const parsed = text.trim() ? parseQuickAdd(text, today, minutesNow(), monthFirst) : undefined;
  const chip = parsed?.dayKey ? [parsed.dayKey === today ? 'Today' : parsed.dayKey === addDays(today, 1) ? 'Tomorrow' : formatShort(parsed.dayKey),
    parsed.minutesFromMidnight !== undefined ? formatTime(parsed.minutesFromMidnight) : ''].filter(Boolean).join(' · ') : '';
  function quickAdd(event: React.FormEvent) {
    event.preventDefault();
    if (!parsed?.title) return;
    const sortIndex = Math.max(-1, ...store.tasks().map((t) => t.data.sortIndex)) + 1;
    store.put('task', { title: parsed.title.slice(0, 200), dayKey: parsed.dayKey, minutesFromMidnight: parsed.minutesFromMidnight, isCompleted: false, sortIndex, createdAt: Date.now(), categoryID: category ?? undefined });
    setText('');
  }

  const trashCount = store.trashed().tasks.length;
  return (
    <div className="scroll">
      <div className="page">
        <div className="page-title"><h1 className="title1">To-do</h1></div>
        <CategoryChips selected={category} onSelect={setCategory} />
        <div style={{ marginTop: 12 }}>
          {active.length === 0 ? <Empty icon="seal" text="All clear." /> : groups.map((g) => (
            <section key={g.id} className="todo-group" aria-label={g.title}>
              <button className={`group-head caption${g.id === 'overdue' ? ' overdue' : ''}`} aria-expanded={!closed.has(g.id)} onClick={() => toggleGroup(g.id)}>
                <span>{g.title}</span><span className="count">{g.items.length}</span><i className="rule" aria-hidden="true" /><Icon name={closed.has(g.id) ? 'chevronRight' : 'chevronDown'} small />
              </button>
              {!closed.has(g.id) && g.items.map((t, i) => (
                <TaskRow key={t.id} task={t} checked={ticking.has(t.id)} showDate={g.id !== 'today' && g.id !== 'tomorrow' && g.id !== 'noDate'} menu style={{ animationDelay: `${i * 30}ms` }} onToggle={() => tick(t.id)} />
              ))}
            </section>
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
          <button className="icon-btn accent" aria-label="Add task" disabled={!parsed?.title}><Icon name="plus" /></button>
          {chip && <span className="quick-chip glass" aria-live="polite"><Icon name="calendar" small />{chip}</span>}
        </form>
      </div>
    </div>
  );
}

