import { formatLong } from '../../lib/days.ts';
import type { DayIndex } from '../../lib/markers.ts';
import { Empty } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { EntryCard } from '../EntryCard.tsx';
import { Icon } from '../Icons.tsx';
import { TaskRow } from '../todo/TaskRow.tsx';

/** The selected day's pages and tasks (SPEC §6.2). Tasks tick in place and stay. */
export function DayPanel({ day, index, hidden }: { day: string; index?: DayIndex; hidden: boolean }) {
  const { store, openComposer, openTask } = useDiary();
  const entries = index?.entries ?? [];
  const tasks = index?.tasks ?? [];
  return (
    <section className="day-panel glass" aria-label={formatLong(day)} style={hidden ? { visibility: 'hidden' } : undefined}>
      <header>
        <h2 className="title2">{formatLong(day)}</h2>
        <button className="icon-btn" aria-label="New entry for this day" onClick={() => openComposer({ dayKey: day })}><Icon name="plus" /></button>
      </header>
      <div className="body" key={day}>
        {entries.length === 0 && tasks.length === 0 ? (
          <Empty icon="pages" text="Nothing here yet.">
            <button className="btn small primary" onClick={() => openComposer({ dayKey: day })}>Write</button>
            <button className="btn small" onClick={() => openTask({ dayKey: day })}>Add task</button>
          </Empty>
        ) : (
          <>
            {entries.length > 0 && <h3 className="caption ink3 section-label">Pages</h3>}
            {entries.map((e, i) => <EntryCard key={e.id} entry={e} style={{ animationDelay: `${i * 30}ms` }} />)}
            {tasks.length > 0 && <h3 className="caption ink3 section-label">Tasks</h3>}
            {tasks.map((t, i) => (
              <TaskRow key={t.id} task={t} style={{ animationDelay: `${(entries.length + i) * 30}ms` }}
                onToggle={() => store.put('task', { isCompleted: !t.data.isCompleted, completedAt: t.data.isCompleted ? undefined : Date.now() }, t.id)} />
            ))}
          </>
        )}
      </div>
    </section>
  );
}
