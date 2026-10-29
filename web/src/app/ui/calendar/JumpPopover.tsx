import { useEffect, useRef, useState } from 'react';
import { type Month } from '../../lib/days.ts';
import type { DayIndex } from '../../lib/markers.ts';
import { Icon } from '../Icons.tsx';

/** Jump (SPEC §6.3): a year stepper back to 1900, twelve months with a dot where there are entries. */
export function JumpPopover({ month, index, onPick, onToday, onClose }: {
  month: Month; index: Map<string, DayIndex>; onPick: (m: Month) => void; onToday: () => void; onClose: () => void;
}) {
  const [year, setYear] = useState(month.year);
  const ref = useRef<HTMLDivElement>(null);
  const max = new Date().getFullYear() + 10;
  useEffect(() => {
    const away = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && onClose();
    const key = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    setTimeout(() => document.addEventListener('click', away));
    document.addEventListener('keydown', key);
    return () => { document.removeEventListener('click', away); document.removeEventListener('keydown', key); };
  }, []);
  const withEntries = new Set([...index.entries()].filter(([, d]) => d.entries.length).map(([day]) => day.slice(0, 7)));
  return (
    <div ref={ref} className="menu glass" style={{ left: 0, right: 'auto', top: 56, width: 300, padding: 14, gap: 12 }} role="dialog" aria-label="Jump to a month">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button className="icon-btn plain" aria-label="Previous year" disabled={year <= 1900} onClick={() => setYear(year - 1)}><Icon name="chevronLeft" /></button>
        <input className="display" style={{ fontSize: 40, width: 130, textAlign: 'center', border: 0, background: 'none' }} inputMode="numeric" aria-label="Year"
          value={year} onChange={(e) => { const y = Number(e.target.value.replace(/\D/g, '').slice(0, 4)); if (y) setYear(Math.min(max, y)); }} />
        <button className="icon-btn plain" aria-label="Next year" disabled={year >= max} onClick={() => setYear(year + 1)}><Icon name="chevronRight" /></button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
        {Array.from({ length: 12 }, (_, m) => {
          const key = `${year}-${String(m + 1).padStart(2, '0')}`;
          const current = year === month.year && m === month.month;
          return (
            <button key={m} className="chip" aria-pressed={current} style={{ justifyContent: 'center', position: 'relative' }} onClick={() => onPick({ year: Math.max(1900, year), month: m })}>
              {new Intl.DateTimeFormat('en-GB', { month: 'short' }).format(new Date(2024, m, 1))}
              {withEntries.has(key) && <i className="dot" style={{ position: 'absolute', bottom: 3, width: 4, height: 4, background: 'var(--ember)' }} aria-label="has entries" />}
            </button>
          );
        })}
      </div>
      <button className="btn primary small" onClick={onToday}>Go to today</button>
    </div>
  );
}
