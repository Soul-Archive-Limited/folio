import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState, useSyncExternalStore } from 'react';
import type { Me } from '../lib/api.ts';
import type { DataKey } from '../lib/crypto.ts';
import { todayKey } from '../lib/days.ts';
import { clearPhotoCache } from '../lib/photos.ts';
import { DiaryStore } from '../lib/store.ts';
import { SyncEngine } from '../lib/sync.ts';
import { Toasts } from './common.tsx';
import { type ComposerRequest, type Diary, DiaryContext, type Tab, type TaskRequest, type Toast, useDiary } from './context.tsx';
import { Avatar } from './Avatar.tsx';
import { Icon, Mark } from './Icons.tsx';
import CalendarView from './calendar/CalendarView.tsx';

const loadComposer = () => import('./Composer.tsx');
const loadJournal = () => import('./journal/JournalView.tsx');
const loadTodo = () => import('./todo/TodoView.tsx');
const Composer = lazy(loadComposer);
const EntryDetail = lazy(() => import('./EntryDetail.tsx'));
const TaskComposer = lazy(() => import('./todo/TaskComposer.tsx'));
const JournalView = lazy(loadJournal);
const TodoView = lazy(loadTodo);
const ProfileView = lazy(() => import('./profile/ProfileView.tsx'));
const Search = lazy(() => import('./Search.tsx'));
const Welcome = lazy(() => import('./Welcome.tsx'));
const Shortcuts = lazy(() => import('./Help.tsx').then((m) => ({ default: m.Shortcuts })));
const MarksKey = lazy(() => import('./Help.tsx').then((m) => ({ default: m.MarksKey })));

/** Fetches the composer (Tiptap) and the other tabs once the browser is idle, so the first
 *  "New entry" doesn't stall while its code downloads and parses (Phase 13: 158 ms). */
function preloadWhenIdle() {
  const run = () => { void loadComposer(); void loadJournal(); void loadTodo(); };
  if ('requestIdleCallback' in window) requestIdleCallback(run, { timeout: 4000 });
  else setTimeout(run, 1500);
}

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
  // The shell reads the synced settings itself (theme, font, sidebar name and picture), so it
  // re-renders on every store change — a change from another device shows at once (Batch L
  // sync matrix: without this the sidebar and theme waited for some other re-render).
  useSyncExternalStore(store.subscribe, store.getRevision);
  const [route, setRoute] = useState(location.pathname + location.search);
  const [composer, setComposer] = useState<ComposerRequest | null>(null);
  const [task, setTask] = useState<TaskRequest | null>(null);
  const [entry, setEntry] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);
  useEffect(preloadWhenIdle, []);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [selectedDay, setSelectedDay] = useState(todayKey());
  const [help, setHelp] = useState<'shortcuts' | 'marks' | null>(null);
  const shortcut = useRef<{ entry: () => void; task: () => void }>(undefined);
  const [loaded, setLoaded] = useState(false);
  const [welcomed, setWelcomed] = useState(() => { try { return localStorage.getItem(`folio.welcomed.${me.userId}`) === '1'; } catch { return true; } });

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
    // "/" or ⌘K / Ctrl-K opens search (Batch J); Batch L adds the rest of the keyboard (Help.tsx),
    // never while typing, with a sheet or menu open, or with a modifier held.
    const onKey = (event: KeyboardEvent) => {
      const typing = (event.target as HTMLElement | null)?.closest?.('input, textarea, select, [contenteditable]');
      if ((event.key === 'k' && (event.metaKey || event.ctrlKey)) || (event.key === '/' && !typing)) {
        event.preventDefault();
        setSearching(true);
        return;
      }
      if (typing || event.metaKey || event.ctrlKey || event.altKey || document.querySelector('.sheet, .modal, .menu, .print-book, .welcome')) return;
      const paths: Record<string, string> = { '1': '/app', '2': '/app/journal', '3': '/app/todo', '4': '/app/profile' };
      const key = event.key;
      if (paths[key]) navigate(paths[key]);
      else if (key === 'n' || key === 'N') shortcut.current?.entry();
      else if (key === 't' || key === 'T') shortcut.current?.task();
      else if (key === '?') setHelp('shortcuts');
      else if (key === '[' || key === ']') window.dispatchEvent(new CustomEvent('folio:month', { detail: key === ']' ? 1 : -1 }));
      else if (key === 'g' || key === 'G') window.dispatchEvent(new Event('folio:today'));
      else return;
      event.preventDefault();
    };
    window.addEventListener('keydown', onKey);
    return () => {
      engine.stop();
      window.removeEventListener('popstate', pop);
      window.removeEventListener('keydown', onKey);
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
    me, store, engine, key: dataKey, route, navigate, toast, selectedDay, showHelp: setHelp,
    openComposer: (request = {}) => { setEntry(null); setComposer(request); },
    openTask: (request = {}) => setTask(request),
    openEntry: (id) => setEntry(id),
    showDay: (day) => { setSelectedDay(day); navigate('/app'); },
    signOut: async () => { engine.stop(); onSignOut(); },
    lock: () => {},
  };
  shortcut.current = { entry: () => diary.openComposer({ dayKey: tabOf(route) === 'calendar' ? selectedDay : undefined }), task: () => diary.openTask({ dayKey: tabOf(route) === 'calendar' ? selectedDay : undefined }) };
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
          <button className="nav-item" onClick={() => setSearching(true)} title="Search (/)">
            <Icon name="search" /><span>Search</span>
          </button>
          <button className="btn primary new" onClick={() => tab === 'todo' ? diary.openTask({}) : diary.openComposer({ dayKey: tab === 'calendar' ? selectedDay : undefined })} title={tab === 'todo' ? 'New task' : 'New entry'}>
            <Icon name="plus" /><span>{tab === 'todo' ? 'New task' : 'New entry'}</span>
          </button>
          <button className="me" onClick={() => navigate('/app/profile')} title="Profile">
            <Avatar settings={settings} fallback={name || me.email || 'F'} />
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
        <button onClick={() => setSearching(true)}><Icon name="search" />Search</button>
      </nav>
      {tab !== 'profile' && !composer && !entry && !task && (
        // On To-do the quick-add bar has its own + (as on the iPhone), so phones show one button.
        <FloatingAdd tab={tab} hideOnPhone={tab === 'todo'} onEntry={() => diary.openComposer({ dayKey: tab === 'calendar' ? selectedDay : undefined })}
          onTask={() => diary.openTask({ dayKey: tab === 'calendar' ? selectedDay : undefined })} />
      )}
      <Suspense fallback={null}>
        {composer && <Composer request={composer} day={selectedDay} onDayChange={selectDay} onClose={() => setComposer(null)} />}
        {entry && <EntryDetail id={entry} onClose={() => setEntry(null)} />}
        {task && <TaskComposer request={task} onClose={() => setTask(null)} />}
        {searching && <Search tasksOnly={tab === 'todo'} onClose={() => setSearching(false)} />}
        {loaded && !welcomed && <Welcome onDone={() => setWelcomed(true)} />}
        {help === 'shortcuts' && <Shortcuts onClose={() => setHelp(null)} />}
        {help === 'marks' && <MarksKey onClose={() => setHelp(null)} />}
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

/** The floating + (SPEC §2): tap = new entry (To-do: new task); long-press or right-click = both (Batch K). */
function FloatingAdd({ tab, onEntry, onTask, hideOnPhone }: { tab: string; onEntry: () => void; onTask: () => void; hideOnPhone?: boolean }) {
  const [menu, setMenu] = useState(false);
  const press = useRef<ReturnType<typeof setTimeout>>(undefined);
  const held = useRef(false);
  const primary = tab === 'todo' ? onTask : onEntry;
  return (
    <>
      <button className={`fab icon-btn accent${hideOnPhone ? ' hide-phone' : ''}`} aria-label={tab === 'todo' ? 'New task' : 'New entry'} aria-haspopup="menu"
        onClick={() => { if (held.current) { held.current = false; return; } primary(); }}
        onContextMenu={(e) => { e.preventDefault(); setMenu(true); }}
        onPointerDown={(e) => {
          if (e.pointerType === 'mouse') return;
          held.current = false;
          press.current = setTimeout(() => { held.current = true; setMenu(true); }, 450);
        }}
        onPointerUp={() => clearTimeout(press.current)} onPointerLeave={() => clearTimeout(press.current)} onPointerCancel={() => clearTimeout(press.current)}>
        <Icon name="plus" />
      </button>
      {menu && (
        <div className="modal-host" style={{ background: 'none', display: 'block' }} onClick={() => setMenu(false)}>
          <div className="menu glass fab-menu" role="menu">
            <button role="menuitem" autoFocus onClick={onEntry}><Icon name="edit" small />New entry</button>
            <button role="menuitem" onClick={onTask}><Icon name="todo" small />New task</button>
          </div>
        </div>
      )}
    </>
  );
}
