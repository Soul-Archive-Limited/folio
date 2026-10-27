import { useEffect, useRef, useState } from 'react';
import { LazyMotion, domAnimation, m, AnimatePresence, useReducedMotion } from 'motion/react';
import './hero-calendar.css';

/**
 * A live HTML/CSS recreation of Folio's calendar for the hero phone (SPEC §11.2). The loop:
 * the composer half sheet rises over October and an entry types itself, Save drops a photo
 * tile into today's cell, then the month swipes to November and back. Reduced Motion shows
 * the finished frame; the loop pauses while the phone is off screen or the tab is hidden.
 */

type Phase = 'rest' | 'sheet' | 'saved' | 'next' | 'back';
const timeline: [Phase, number][] = [
  ['rest', 1300],
  ['sheet', 4200],
  ['saved', 2200],
  ['next', 1700],
  ['back', 2200],
];

const TODAY = 27;
const TITLE = 'Train to Edinburgh';
const BODY = 'Four hours of fields, rain and a very good sandwich.';
const WEEKDAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

type Marker = { photo?: string; dots?: string[]; ring?: 'open' | 'done' };
const october: Record<number, Marker> = {
  3: { photo: 'sea' }, 6: { dots: ['ocean', 'ember'] }, 9: { ring: 'done' }, 11: { photo: 'field' },
  14: { dots: ['sage'] }, 16: { ring: 'done' }, 18: { photo: 'dusk' }, 20: { dots: ['rose'] },
  22: { photo: 'hills' }, 24: { dots: ['violet', 'ocean'] }, 29: { ring: 'open' }, 30: { ring: 'open' },
};
const november: Record<number, Marker> = { 2: { ring: 'open' }, 7: { dots: ['rose'] }, 14: { ring: 'open' } };

/** 42 cells, Monday first: day number and whether it's in the month. */
function grid(year: number, month: number) {
  const first = new Date(Date.UTC(year, month, 1));
  const lead = (first.getUTCDay() + 6) % 7;
  return Array.from({ length: 42 }, (_, i) => {
    const date = new Date(Date.UTC(year, month, 1 + i - lead));
    return { day: date.getUTCDate(), inMonth: date.getUTCMonth() === month, key: date.toISOString().slice(0, 10) };
  });
}

function Month({ year, month, markers, savedPhoto, selected }: {
  year: number; month: number; markers: Record<number, Marker>; savedPhoto: boolean; selected: boolean;
}) {
  const isOctober = month === 9;
  return (
    <div className="hc-month">
      {grid(year, month).map((cell) => {
        const marker = cell.inMonth ? markers[cell.day] : undefined;
        const isToday = isOctober && cell.inMonth && cell.day === TODAY;
        const photo = marker?.photo ?? (isToday && savedPhoto ? 'train' : undefined);
        const classes = ['hc-cell'];
        if (!cell.inMonth) classes.push('hc-out');
        if (isToday && !photo) classes.push(selected ? 'hc-selected' : 'hc-today');
        if (photo) classes.push('hc-photo');
        return (
          <div key={cell.key} className={classes.join(' ')}>
            <AnimatePresence initial={false}>
              {photo && (
                <m.span
                  key="tile"
                  className={`hc-tile hc-${photo}`}
                  initial={{ scale: 0.4, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ type: 'spring', duration: 0.5, bounce: 0.35 }}
                />
              )}
            </AnimatePresence>
            <span className="hc-num">{cell.day}</span>
            {isToday && photo && selected && <span className="hc-ring-selected" />}
            {marker?.dots && (
              <span className="hc-dots">{marker.dots.map((d, i) => <i key={i} className={`hc-dot-${d}`} />)}</span>
            )}
            {marker?.ring && <span className={`hc-ring hc-ring-${marker.ring}`} />}
          </div>
        );
      })}
    </div>
  );
}

export default function HeroCalendar() {
  const reduceMotion = useReducedMotion();
  const [step, setStep] = useState(0);
  const [typed, setTyped] = useState(0);
  const [visible, setVisible] = useState(true);
  const root = useRef<HTMLDivElement>(null);
  const total = TITLE.length + BODY.length;

  const phase: Phase = reduceMotion ? 'back' : timeline[step][0];
  const sheetUp = phase === 'sheet';
  const saved = reduceMotion || step >= 2;
  const showsNovember = phase === 'next';
  const typedChars = reduceMotion ? total : typed;

  // Pause off screen and in background tabs.
  useEffect(() => {
    const element = root.current;
    if (!element) return;
    const observer = new IntersectionObserver(([entry]) => setVisible(entry.isIntersecting && !document.hidden));
    observer.observe(element);
    const onVisibility = () => setVisible(!document.hidden);
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      observer.disconnect();
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, []);

  useEffect(() => {
    if (reduceMotion || !visible) return;
    const timer = window.setTimeout(() => {
      const next = (step + 1) % timeline.length;
      if (next === 1) setTyped(0);
      setStep(next);
    }, timeline[step][1]);
    return () => window.clearTimeout(timer);
  }, [step, visible, reduceMotion]);

  // Type the entry while the sheet is up.
  useEffect(() => {
    if (reduceMotion || !visible || !sheetUp || typed >= total) return;
    const timer = window.setTimeout(() => setTyped((n) => n + 1), typed === 0 ? 450 : 34);
    return () => window.clearTimeout(timer);
  }, [sheetUp, typed, total, visible, reduceMotion]);

  const spring = { type: 'spring', duration: 0.6, bounce: 0.12 } as const;
  const title = TITLE.slice(0, Math.min(typedChars, TITLE.length));
  const body = BODY.slice(0, Math.max(0, typedChars - TITLE.length));

  return (
    <LazyMotion features={domAnimation} strict>
      <div
        ref={root}
        className="hc-phone"
        role="img"
        aria-label="Folio on iPhone: an October calendar with photo tiles on the days written about. A new entry, Train to Edinburgh, is written in a half sheet and its photo appears on Tuesday 27 October."
      >
        <div className="hc-screen" aria-hidden="true">
          <div className="hc-aura" />
          <div className="hc-status"><span>9:41</span><span className="hc-island" /><span className="hc-battery" /></div>
          <div className="hc-header">
            <m.div
              className="hc-title"
              key={showsNovember ? 'nov' : 'oct'}
              initial={reduceMotion ? false : { opacity: 0, filter: 'blur(4px)' }}
              animate={{ opacity: 1, filter: 'blur(0px)' }}
              transition={{ duration: 0.35 }}
            >
              {showsNovember ? 'November' : 'October'} <span>2026</span>
            </m.div>
          </div>
          <div className="hc-weekdays">{WEEKDAYS.map((d, i) => <span key={i}>{d}</span>)}</div>
          <div className="hc-pager">
            <m.div className="hc-track" animate={{ x: showsNovember ? '-50%' : '0%' }} transition={spring}>
              <Month year={2026} month={9} markers={october} savedPhoto={saved} selected={!showsNovember} />
              <Month year={2026} month={10} markers={november} savedPhoto={false} selected={false} />
            </m.div>
          </div>
          <div className="hc-panel">
            <div className="hc-panel-title">Tuesday 27 October</div>
            <AnimatePresence mode="popLayout" initial={false}>
              {saved ? (
                <m.div key="entry" className="hc-card" initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={spring}>
                  <span className="hc-card-photo hc-train" />
                  <span className="hc-card-text"><b>{TITLE}</b><small>{BODY}</small></span>
                </m.div>
              ) : (
                <m.div key="empty" className="hc-empty" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
                  Nothing here yet.
                </m.div>
              )}
            </AnimatePresence>
          </div>
          <div className="hc-plus">+</div>
          <div className="hc-tabbar">
            <span className="hc-tab hc-tab-on" /><span className="hc-tab" /><span className="hc-tab" /><span className="hc-tab" />
          </div>
          <m.div
            className="hc-sheet"
            initial={false}
            animate={{ y: sheetUp ? '0%' : '105%' }}
            transition={{ type: 'spring', duration: 0.55, bounce: 0.1 }}
          >
            <div className="hc-grabber" />
            <div className="hc-sheet-bar">
              <span>Cancel</span>
              <span className="hc-date-pill">Tue 27 Oct</span>
              <span className="hc-save">Save</span>
            </div>
            <div className="hc-sheet-title">{title}<i className="hc-caret" /></div>
            <div className="hc-sheet-body">{body}</div>
            <div className="hc-strip"><span className="hc-strip-photo hc-train" /></div>
          </m.div>
        </div>
      </div>
    </LazyMotion>
  );
}
