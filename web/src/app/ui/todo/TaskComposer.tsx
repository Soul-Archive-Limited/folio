import { useState } from 'react';
import { pad, todayKey } from '../../lib/days.ts';
import { CategoryChips, Sheet, useCloseSheet } from '../common.tsx';
import { type TaskRequest, useDiary } from '../context.tsx';

/** Task composer (SPEC §6.8): title, notes, date and time toggles, category; Delete for existing. */
export default function TaskComposer({ request, onClose }: { request: TaskRequest; onClose: () => void }) {
  return (
    <Sheet label={request.taskId ? 'Edit task' : 'New task'} onClose={onClose}>
      <Body request={request} />
    </Sheet>
  );
}

function Body({ request }: { request: TaskRequest }) {
  const { store, toast } = useDiary();
  const close = useCloseSheet();
  const existing = request.taskId ? store.get('task', request.taskId) : undefined;
  const [title, setTitle] = useState(existing?.data.title ?? '');
  const [notes, setNotes] = useState(existing?.data.notes ?? '');
  const [dayKey, setDayKey] = useState<string | undefined>(existing ? existing.data.dayKey : request.dayKey);
  const [minutes, setMinutes] = useState<number | undefined>(existing?.data.minutesFromMidnight);
  const [category, setCategory] = useState<string | null>(existing?.data.categoryID ?? store.settings?.defaultCategoryID ?? null);

  function save(event: React.FormEvent) {
    event.preventDefault();
    if (!title.trim()) return;
    const sortIndex = existing?.data.sortIndex ?? Math.max(-1, ...store.tasks().map((t) => t.data.sortIndex)) + 1;
    store.put('task', {
      title: title.trim().slice(0, 200), notes: notes.trim() ? notes.slice(0, 2000) : undefined, dayKey, minutesFromMidnight: dayKey ? minutes : undefined,
      categoryID: category ?? undefined, sortIndex, ...(existing ? {} : { isCompleted: false, createdAt: Date.now() }),
    }, existing?.id);
    close();
  }

  return (
    <form onSubmit={save} style={{ display: 'contents' }}>
      <div className="sheet-bar">
        <button type="button" className="btn small" onClick={close}>Cancel</button>
        <span className="headline">{existing ? 'Edit task' : 'New task'}</span>
        <button className="btn small primary" disabled={!title.trim()}>Save</button>
      </div>
      <div className="sheet-body" style={{ display: 'grid', gap: 14, alignContent: 'start' }}>
        <input className="field" placeholder="Title" aria-label="Title" maxLength={200} required autoFocus value={title} onChange={(e) => setTitle(e.target.value)} />
        <textarea className="field" placeholder="Notes" aria-label="Notes" rows={3} maxLength={2000} value={notes} onChange={(e) => setNotes(e.target.value)} />
        <div className="group glass">
          <label className="row"><span className="grow">Date</span>
            <input type="checkbox" className="toggle" checked={!!dayKey} onChange={(e) => setDayKey(e.target.checked ? request.dayKey ?? todayKey() : undefined)} />
          </label>
          {dayKey && <div className="row"><input type="date" className="field" aria-label="Date" min="1900-01-01" value={dayKey} onChange={(e) => e.target.value && setDayKey(e.target.value)} /></div>}
          {dayKey && (
            <label className="row"><span className="grow">Time</span>
              <input type="checkbox" className="toggle" checked={minutes !== undefined} onChange={(e) => setMinutes(e.target.checked ? 9 * 60 : undefined)} />
            </label>
          )}
          {dayKey && minutes !== undefined && (
            <div className="row"><input type="time" className="field" aria-label="Time" value={`${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`}
              onChange={(e) => { const [h, m] = e.target.value.split(':').map(Number); if (h !== undefined && m !== undefined) setMinutes(h * 60 + m); }} /></div>
          )}
        </div>
        <CategoryChips selected={category} onSelect={setCategory} allLabel="None" />
        {existing && (
          <button type="button" className="btn danger" onClick={() => {
            store.trash('task', existing.id);
            toast('Moved to Recently Deleted', { label: 'Undo', run: () => store.restore('task', existing.id) });
            close();
          }}>Delete task</button>
        )}
      </div>
    </form>
  );
}
