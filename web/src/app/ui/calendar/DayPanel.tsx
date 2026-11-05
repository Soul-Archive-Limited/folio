import { formatLong } from '../../lib/days.ts';
import type { DayIndex } from '../../lib/markers.ts';
import { Empty } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { EntryCard } from '../EntryCard.tsx';
import { Icon } from '../Icons.tsx';
import { MoodGlyph } from '../Mood.tsx';
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
        <OnThisDay day={day} />
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
                onToggle={() => store.setTaskDone(t.id, !t.data.isCompleted)} />
            ))}
          </>
        )}
      </div>
    </section>
  );
}

/** Pages from this date in earlier years, newest first (Batch J). */
function OnThisDay({ day }: { day: string }) {
  const { store, openEntry } = useDiary();
  const earlier = store.entries().filter((e) => e.data.dayKey.slice(5) === day.slice(5) && e.data.dayKey < day)
    .sort((a, b) => b.data.dayKey.localeCompare(a.data.dayKey));
  if (!earlier.length) return null;
  return (
    <div className="on-this-day">
      <h3 className="caption" style={{ color: 'var(--ember-text)' }}>On this day</h3>
      {earlier.slice(0, 3).map((e) => (
        <button key={e.id} onClick={() => openEntry(e.id)}>
          <b>{e.data.dayKey.slice(0, 4)}</b><span>{e.data.title || 'Untitled'}</span>{e.data.mood ? <MoodGlyph mood={e.data.mood} size={12} /> : null}
        </button>
      ))}
      {earlier.length > 3 && <p className="caption ink3">and {earlier.length - 3} more</p>}
    </div>
  );
}
