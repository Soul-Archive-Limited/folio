import { memo, useRef } from 'react';
import { formatLong, type Month, monthOf } from '../../lib/days.ts';
import { type DayIndex, markerFor, matchesFilter } from '../../lib/markers.ts';
import { categoryColor } from '../../lib/payloads.ts';
import { PhotoImg } from '../common.tsx';
import { useDiary } from '../context.tsx';

interface Props {
  day: string; month: Month; today: string; selected: boolean; index?: DayIndex; filter: string | null; showTiles: boolean;
  onSelect: () => void; onMenu: (x: number, y: number) => void;
}

/** One day: photo tile (+N), category dots, task ring, today, selected, out-of-month, filter fade. */
export const DayCell = memo(function DayCell({ day, month, today, selected, index, filter, showTiles, onSelect, onMenu }: Props) {
  const { store } = useDiary();
  const marker = markerFor(store, index);
  const press = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const out = monthOf(day).month !== month.month;
  const photo = showTiles && !out ? marker.thumbnailPhotoId : undefined;
  const faded = !!filter && (marker.entryCount > 0 || marker.openTasks + marker.doneTasks > 0) && !matchesFilter(marker, filter);
  const tasks = marker.openTasks + marker.doneTasks;
  const label = [
    formatLong(day),
    day === today ? 'today' : '',
    marker.entryCount ? `${marker.entryCount} ${marker.entryCount === 1 ? 'entry' : 'entries'}` : '',
    marker.doneTasks ? `${marker.doneTasks} ${marker.doneTasks === 1 ? 'task' : 'tasks'} done` : '',
    marker.openTasks ? `${marker.openTasks} open ${marker.openTasks === 1 ? 'task' : 'tasks'}` : '',
  ].filter(Boolean).join(', ');
  const classes = ['cell', out && 'out', day === today && 'today', selected && 'selected', photo && 'photo', faded && 'faded'].filter(Boolean).join(' ');

  return (
    <button className={classes} data-day={day} role="gridcell" aria-selected={selected} aria-label={label} tabIndex={selected ? 0 : -1}
      onClick={onSelect}
      onContextMenu={(e) => { e.preventDefault(); onMenu(e.clientX, e.clientY); }}
      onPointerDown={(e) => {
        if (e.pointerType === 'mouse') return;
        const { clientX, clientY } = e;
        press.current = setTimeout(() => onMenu(clientX, clientY), 550);
      }}
      onPointerUp={() => clearTimeout(press.current)} onPointerLeave={() => clearTimeout(press.current)} onPointerCancel={() => clearTimeout(press.current)}>
      {photo && <PhotoImg id={photo} rendition="thumb" />}
      <span className="n">{Number(day.slice(8))}</span>
      {photo && marker.extraEntryCount > 0 && <span className="more">+{marker.extraEntryCount}</span>}
      {!photo && marker.dots.length > 0 && !out && (
        <span className="dots" aria-hidden="true">{marker.dots.map((id, i) => <i key={i} style={{ ['--c' as string]: id ? categoryColor(store.category(id)?.data.colorKey) : undefined }} />)}</span>
      )}
      {tasks > 0 && !out && <span className={`ring${marker.openTasks === 0 ? ' done' : ''}`} aria-hidden="true" />}
    </button>
  );
});
