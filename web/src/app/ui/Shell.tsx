import { lazy, Suspense, useCallback, useEffect, useMemo, useState } from 'react';
import type { Me } from '../lib/api.ts';
import type { DataKey } from '../lib/crypto.ts';
import { todayKey } from '../lib/days.ts';
import { clearPhotoCache } from '../lib/photos.ts';
import { DiaryStore } from '../lib/store.ts';
import { SyncEngine } from '../lib/sync.ts';
import { Toasts } from './common.tsx';
import { type ComposerRequest, type Diary, DiaryContext, type Tab, type TaskRequest, type Toast, useDiary } from './context.tsx';
import { Icon, Mark } from './Icons.tsx';
import CalendarView from './calendar/CalendarView.tsx';

const Composer = lazy(() => import('./Composer.tsx'));
const EntryDetail = lazy(() => import('./EntryDetail.tsx'));
const TaskComposer = lazy(() => import('./todo/TaskComposer.tsx'));
const JournalView = lazy(() => import('./journal/JournalView.tsx'));
const TodoView = lazy(() => import('./todo/TodoView.tsx'));
const ProfileView = lazy(() => import('./profile/ProfileView.tsx'));

const TABS: { tab: Tab; label: string; icon: string; path: string }[] = [
  { tab: 'calendar', label: 'Calendar', icon: 'calendar', path: '/app' },
  { tab: 'journal', label: 'Journal', icon: 'journal', path: '/app/journal' },
  { tab: 'todo', label: 'To-do', icon: 'todo', path: '/app/todo' },
  { tab: 'profile', label: 'Profile', icon: 'profile', path: '/app/profile' },
];

const tabOf = (path: string): Tab =>
  path.startsWith('/app/journal') ? 'journal' : path.startsWith('/app/todo') ? 'todo' : path.startsWith('/app/profile') || path.startsWith('/app/settings') ? 'profile' : 'calendar';

/**
 * The signed-in, unlocked app: glass sidebar (≥ 1024 px, a rail from 768) or the floating
 * tab bar on phones (SPEC §11.3), with the composer and entry detail as sheets.
 */
export default function Shell({ me, dataKey, onSignOut, onSessionEnded }: { me: Me; dataKey: DataKey; onSignOut: () => void; onSessionEnded: () => void }) {
  const store = useMemo(() => new DiaryStore(me.userId), [me.userId]);
  const engine = useMemo(() => new SyncEngine(store, dataKey), [store, dataKey]);
  const [route, setRoute] = useState(location.pathname + location.search);
  const [composer, setComposer] = useState<ComposerRequest | null>(null);
  const [task, setTask] = useState<TaskRequest | null>(null);
  const [entry, setEntry] = useState<string | null>(null);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [selectedDay, setSelectedDay] = useState(todayKey());
  const [, setLoaded] = useState(false);

  const toast = useCallback((text: string, action?: Toast['action'], seconds = 4) => {
    const id = Date.now() + Math.random();
    setToasts((list) => [...list.slice(-2), { id, text, action, seconds }]);
    setTimeout(() => setToasts((list) => list.filter((t) => t.id !== id)), seconds * 1000);
  }, []);

  useEffect(() => {
    engine.onProblem = (message) => toast(message, undefined, 6);
    engine.onSignedOut = onSessionEnded;
    void engine.start().then(() => setLoaded(true));
    const pop = () => setRoute(location.pathname + location.search);
    window.addEventListener('popstate', pop);
    return () => {
      engine.stop();
      window.removeEventListener('popstate', pop);
      clearPhotoCache();
    };
  }, [engine]);

  // Theme and writing font follow the synced settings (SPEC §6.9); remembered for the next load.
  const settings = store.settings;
  useEffect(() => {
    const theme = settings?.appearance === 'light' || settings?.appearance === 'dark' ? settings.appearance : '';
    if (theme) document.documentElement.dataset.theme = theme;
    else delete document.documentElement.dataset.theme;
    document.documentElement.dataset.font = settings?.writingFont === 'sfPro' ? 'sfPro' : 'newYork';
    try { localStorage.setItem('folio.theme', theme); } catch { /* private mode */ }
  }, [settings?.appearance, settings?.writingFont]);

  const navigate = useCallback((path: string) => {
    if (path !== location.pathname + location.search) history.pushState(null, '', path);
    setRoute(path);
  }, []);

  const diary: Diary = {
    me, store, engine, key: dataKey, route, navigate, toast, selectedDay,
    openComposer: (request = {}) => { setEntry(null); setComposer(request); },
    openTask: (request = {}) => setTask(request),
    openEntry: (id) => setEntry(id),
    showDay: (day) => { setSelectedDay(day); navigate('/app'); },
    signOut: async () => { engine.stop(); onSignOut(); },
    lock: () => {},
  };
  // Day selection lives here so the composer can move an entry by tapping another day.
  const selectDay = (day: string) => setSelectedDay(day);

  const tab = tabOf(route);
  const name = settings?.displayName?.trim();
  return (
    <DiaryContext.Provider value={diary}>
      <div className="aura" aria-hidden="true"><i /><i /><i /></div>
      <div className="app">
        <nav className="sidebar glass" aria-label="Folio">
          <div className="brand"><Mark /><span>Folio</span></div>
          {TABS.map((t) => (
            <button key={t.tab} className="nav-item" aria-current={tab === t.tab ? 'page' : undefined} onClick={() => navigate(t.path)} title={t.label}>
              <Icon name={t.icon} /><span>{t.label}</span>
            </button>
          ))}
          <button className="btn primary new" onClick={() => tab === 'todo' ? diary.openTask({}) : diary.openComposer({ dayKey: tab === 'calendar' ? selectedDay : undefined })} title={tab === 'todo' ? 'New task' : 'New entry'}>
            <Icon name="plus" /><span>{tab === 'todo' ? 'New task' : 'New entry'}</span>
          </button>
          <button className="me" onClick={() => navigate('/app/profile')} title="Profile">
            <span className="avatar" aria-hidden="true">{(name || me.email || 'F').slice(0, 1).toUpperCase()}</span>
            <span className="grow" style={{ minWidth: 0 }}>
              <span style={{ display: 'block', fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis' }}>{name || 'You'}</span>
              <SyncLine />
            </span>
          </button>
        </nav>
        <main className="main" id="main">
          <Suspense fallback={null}>
            {tab === 'calendar' && <CalendarView selected={selectedDay} onSelect={selectDay} composing={!!composer} />}
            {tab === 'journal' && <JournalView />}
            {tab === 'todo' && <TodoView />}
            {tab === 'profile' && <ProfileView />}
          </Suspense>
        </main>
      </div>
      <nav className="tabbar glass" aria-label="Folio">
        {TABS.map((t) => (
          <button key={t.tab} aria-current={tab === t.tab ? 'page' : undefined} onClick={() => navigate(t.path)}>
            <Icon name={t.icon} />{t.label}
          </button>
        ))}
      </nav>
      {tab !== 'profile' && (
        <button className="fab icon-btn ember" aria-label={tab === 'todo' ? 'New task' : 'New entry'}
          onClick={() => tab === 'todo' ? diary.openTask({}) : diary.openComposer({ dayKey: tab === 'calendar' ? selectedDay : undefined })}>
          <Icon name="plus" />
        </button>
      )}
      <Suspense fallback={null}>
        {composer && <Composer request={composer} day={selectedDay} onDayChange={selectDay} onClose={() => setComposer(null)} />}
        {entry && <EntryDetail id={entry} onClose={() => setEntry(null)} />}
        {task && <TaskComposer request={task} onClose={() => setTask(null)} />}
      </Suspense>
      <Toasts toasts={toasts} dismiss={(id) => setToasts((list) => list.filter((t) => t.id !== id))} />
    </DiaryContext.Provider>
  );
}

export const SYNC_TEXT = { upToDate: 'Up to date', syncing: 'Syncing…', offline: 'Offline', error: "Couldn't sync" } as const;

function SyncLine() {
  const { engine } = useDiary();
  const text = SYNC_TEXT[engine.status];
  return <span className="ink3" style={{ display: 'block', fontSize: 12 }}>{text}</span>;
}
