import { useState, type CSSProperties } from 'react';
import { formatDayMonth, formatTime, todayKey } from '../../lib/days.ts';
import { categoryColor, type TaskData } from '../../lib/payloads.ts';
import type { Rec } from '../../lib/store.ts';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';

/** A task: circular checkbox in its category colour, title, one line of notes, date chip. */
export function TaskRow({ task, onToggle, checked, showDate, style, menu }: {
  task: Rec<TaskData>; onToggle: () => void; checked?: boolean; showDate?: boolean; style?: CSSProperties; menu?: boolean;
}) {
  const { store, openTask, toast } = useDiary();
  const [open, setOpen] = useState(false);
  const done = checked ?? task.data.isCompleted;
  const category = store.category(task.data.categoryID);
  const day = task.data.dayKey;
  const overdue = !!day && !task.data.isCompleted && day < todayKey();
  const when = day ? [day === todayKey() ? 'Today' : formatDayMonth(day), task.data.minutesFromMidnight !== undefined ? formatTime(task.data.minutesFromMidnight) : ''].filter(Boolean).join(' ') : '';
  return (
    <div className={`task${done ? ' done' : ''}`} style={{ ...style, position: 'relative' }}>
      <button className="tick" role="checkbox" aria-checked={done} aria-label={task.data.title}
        style={category ? { ['--c' as string]: categoryColor(category.data.colorKey) } : undefined} onClick={onToggle}>
        <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M3.5 8.5l3 3 6-7" /></svg>
      </button>
      <button className="title" onClick={() => openTask({ taskId: task.id })}>
        <b>{task.data.title}</b>
        {task.data.notes && <small>{task.data.notes.split('\n')[0]}</small>}
      </button>
      {showDate && when && <span className={`when${overdue ? ' overdue' : ''}`}>{when}</span>}
      {menu && (
        <>
          <button className="icon-btn plain menu-btn" aria-label={`More for ${task.data.title}`} aria-expanded={open} onClick={() => setOpen(!open)}><Icon name="more" /></button>
          {open && (
            <div className="menu glass" role="menu" style={{ top: 48 }} onMouseLeave={() => setOpen(false)}>
              <button role="menuitem" onClick={() => { setOpen(false); openTask({ taskId: task.id }); }}><Icon name="edit" small />Edit</button>
              {(['Today', 'Tomorrow', 'Next week'] as const).map((label, i) => (
                <button key={label} role="menuitem" onClick={() => {
                  setOpen(false);
                  const d = new Date(); d.setDate(d.getDate() + [0, 1, 7][i]!);
                  store.put('task', { dayKey: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }, task.id);
                }}><Icon name="calendar" small />{label}</button>
              ))}
              {day && <button role="menuitem" onClick={() => { setOpen(false); store.put('task', { dayKey: undefined, minutesFromMidnight: undefined }, task.id); }}><Icon name="close" small />Remove date</button>}
              <button role="menuitem" className="danger" onClick={() => {
                setOpen(false);
                store.trash('task', task.id);
                toast('Moved to Recently Deleted', { label: 'Undo', run: () => store.restore('task', task.id) });
              }}><Icon name="trash" small />Delete</button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
