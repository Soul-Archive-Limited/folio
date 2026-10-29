import { useMemo, useRef, useState } from 'react';
import { addDays, addMonths, localeFirstWeekday, type Month, monthGrid, monthName, monthOf, todayKey, weekdayNames } from '../../lib/days.ts';
import { indexByDay } from '../../lib/markers.ts';
import { categoryColor } from '../../lib/payloads.ts';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { DayCell } from './DayCell.tsx';
import { DayPanel } from './DayPanel.tsx';
import { JumpPopover } from './JumpPopover.tsx';

/** Calendar (SPEC §6.2): month grid with every cell state, filter, Today, and the day panel. */
export default function CalendarView({ selected, onSelect, composing }: { selected: string; onSelect: (day: string) => void; composing: boolean }) {
  const { store, openComposer, openTask } = useDiary();
  const [month, setMonth] = useState<Month>(monthOf(selected));
  const [direction, setDirection] = useState<'next' | 'prev' | ''>('');
  const [filter, setFilter] = useState<string | null>(null);
  const [filterOpen, setFilterOpen] = useState(false);
  const [jumpOpen, setJumpOpen] = useState(false);
  const [menu, setMenu] = useState<{ day: string; x: number; y: number } | null>(null);
  const swipe = useRef<{ x: number; y: number } | null>(null);

  const firstWeekday = store.settings?.firstWeekday ?? localeFirstWeekday();
  const days = monthGrid(month, firstWeekday);
  const index = useMemo(() => indexByDay(store), [store.revision]);
  const showTiles = useMemo(() => { try { return localStorage.getItem('folio.photoTiles') !== 'off'; } catch { return true; } }, [store.revision]);
  const today = todayKey();
  const onToday = month.year === monthOf(today).year && month.month === monthOf(today).month && selected === today;
  const filterCategory = store.category(filter ?? undefined);

  const go = (n: number) => {
    setDirection(n > 0 ? 'next' : 'prev');
    setMonth(addMonths(month, n));
  };
  const select = (day: string) => {
    const m = monthOf(day);
    if (m.year !== month.year || m.month !== month.month) go((m.year - month.year) * 12 + m.month - month.month);
    onSelect(day);
  };

  function onGridKey(event: React.KeyboardEvent) {
    const steps: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 };
    if (event.key === 'PageDown') { event.preventDefault(); go(1); return; }
    if (event.key === 'PageUp') { event.preventDefault(); go(-1); return; }
    const step = steps[event.key];
    if (step === undefined) return;
    event.preventDefault();
    const next = addDays(selected, step);
    select(next);
    requestAnimationFrame(() => document.querySelector<HTMLElement>(`[data-day="${next}"]`)?.focus());
  }

  return (
    <div className="calendar">
      <section className="cal-main" aria-label="Month">
        <header className="cal-head">
          <div style={{ position: 'relative' }}>
            <button className="month-title" onClick={() => setJumpOpen(!jumpOpen)} aria-expanded={jumpOpen} aria-label={`${monthName(month)} ${month.year}. Jump to a month`}>
              <span className="title1">{monthName(month)}</span><span className="y">{month.year}</span><Icon name="chevronDown" small />
            </button>
            {jumpOpen && <JumpPopover month={month} index={index} onPick={(m) => { setDirection(''); setMonth(m); setJumpOpen(false); }}
              onToday={() => { setJumpOpen(false); setDirection(''); setMonth(monthOf(today)); onSelect(today); }} onClose={() => setJumpOpen(false)} />}
          </div>
          <div className="cal-tools glass">
            <button className="icon-btn plain step" aria-label="Previous month" onClick={() => go(-1)}><Icon name="chevronLeft" /></button>
            <button className="icon-btn plain step" aria-label="Next month" onClick={() => go(1)}><Icon name="chevronRight" /></button>
            <div style={{ position: 'relative' }}>
              <button className="icon-btn plain" aria-label={filterCategory ? `Filter: ${filterCategory.data.name}` : 'Filter by category'} aria-expanded={filterOpen}
                onClick={() => setFilterOpen(!filterOpen)} style={filterCategory ? { color: categoryColor(filterCategory.data.colorKey) } : undefined}>
                <Icon name="filter" />
              </button>
              {filterOpen && (
                <div className="menu glass" style={{ right: 0, top: 50 }} role="menu">
                  <button role="menuitemradio" aria-checked={!filter} onClick={() => { setFilter(null); setFilterOpen(false); }}>All categories{!filter && <Icon name="check" small />}</button>
                  {store.categories().map((c) => (
                    <button key={c.id} role="menuitemradio" aria-checked={filter === c.id} onClick={() => { setFilter(c.id); setFilterOpen(false); }}>
                      <span className="chip" style={{ ['--c' as string]: categoryColor(c.data.colorKey), border: 0, background: 'none', padding: 0 }}><i className="dot" /></span>
                      {c.data.name}{filter === c.id && <Icon name="check" small />}
                    </button>
                  ))}
                </div>
              )}
            </div>
            {!onToday && <button className="btn small primary" onClick={() => { setDirection(''); setMonth(monthOf(today)); onSelect(today); }}>Today</button>}
          </div>
        </header>
        <div className="weekdays caption ink3" aria-hidden="true">{weekdayNames(firstWeekday).map((w) => <span key={w}>{w}</span>)}</div>
        <div className="grid-panel glass"
          onPointerDown={(e) => { if (e.pointerType !== 'mouse') swipe.current = { x: e.clientX, y: e.clientY }; }}
          onPointerUp={(e) => {
            const start = swipe.current;
            swipe.current = null;
            if (!start) return;
            const dx = e.clientX - start.x;
            if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(e.clientY - start.y) * 1.5) go(dx < 0 ? 1 : -1);
          }}>
          <div key={`${month.year}-${month.month}`} className={`grid${direction ? ` slide-${direction}` : ''}`} role="grid" aria-label={`${monthName(month)} ${month.year}`} onKeyDown={onGridKey}>
            {days.map((day) => (
              <DayCell key={day} day={day} month={month} today={today} selected={selected === day} index={index.get(day)} filter={filter} showTiles={showTiles}
                onSelect={() => select(day)} onMenu={(x, y) => setMenu({ day, x, y })} />
            ))}
          </div>
        </div>
      </section>
      <DayPanel day={selected} index={index.get(selected)} hidden={composing} />
      {menu && (
        <div className="modal-host" style={{ background: 'none', display: 'block' }} onClick={() => setMenu(null)}>
          <div className="menu glass" role="menu" style={{ position: 'fixed', left: Math.min(menu.x, innerWidth - 240), top: Math.min(menu.y, innerHeight - 120) }}>
            <button role="menuitem" onClick={() => { onSelect(menu.day); openComposer({ dayKey: menu.day }); }}><Icon name="edit" small />New entry for this day</button>
            <button role="menuitem" onClick={() => { onSelect(menu.day); openTask({ dayKey: menu.day }); }}><Icon name="todo" small />New task for this day</button>
          </div>
        </div>
      )}
    </div>
  );
}
