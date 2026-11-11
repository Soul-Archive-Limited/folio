import { lazy, Suspense, useEffect, useMemo, useState } from 'react';
import { SETTINGS_ID, type SettingsData } from '../../lib/payloads.ts';
import { PAGE_GROUPS, PAGE_TITLES, PROFILE_PAGES, type ProfilePage, searchSettings } from '../../lib/profile-search.ts';
import { Avatar } from '../Avatar.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { EditProfile } from './EditProfile.tsx';
import { PageContent } from './ProfilePages.tsx';

const Devices = lazy(() => import('./Devices.tsx'));
const Invites = lazy(() => import('./Invites.tsx'));
const RecentlyDeleted = lazy(() => import('./RecentlyDeleted.tsx'));

const PAGE_ICONS: Record<ProfilePage, string> = {
  account: 'sync', categories: 'tag', appearance: 'appearance', writing: 'mic', notifications: 'memories',
  widgets: 'widgets', privacy: 'lock', data: 'export', help: 'help',
};

/**
 * Profile (SPEC §6.9, Batch N): search, the profile card with Edit profile, one row of four
 * stats, and grouped rows that each open a page — as on the iPhone. Wide windows (iPad and up)
 * show the rows beside the open page.
 */
export default function ProfileView() {
  const { route } = useDiary();
  const path = route.split('?')[0]!;
  const sub = path.replace(/^\/app\/profile\/?/, '');
  const page = (PROFILE_PAGES as readonly string[]).includes(sub) ? (sub as ProfilePage) : undefined;
  const detail = sub === 'devices' ? <Devices /> : sub === 'invites' ? <Invites /> : sub === 'deleted' ? <RecentlyDeleted />
    : page ? <PageContent page={page} /> : null;
  return (
    <div className="scroll">
      <div className={`page profile-layout${detail ? ' has-detail' : ''}`}>
        <div className="profile-root"><Root active={page ?? (sub === 'devices' || sub === 'invites' ? 'account' : sub === 'deleted' ? 'data' : undefined)} /></div>
        {detail && <div className="profile-detail"><Suspense fallback={null}>{detail}</Suspense></div>}
      </div>
    </div>
  );
}

/** "‹ Profile" above a page; on wide windows the rows are already beside it. */
export function Back({ title, to = '/app/profile' }: { title: string; to?: string }) {
  const { navigate } = useDiary();
  return (
    <div className="page-title" style={{ justifyContent: 'flex-start' }}>
      <button className="icon-btn back-btn" aria-label={to === '/app/profile' ? 'Back to Profile' : 'Back'} onClick={() => navigate(to)}><Icon name="chevronLeft" /></button>
      <h1 className="title1">{title}</h1>
    </div>
  );
}

export function useSettings() {
  const { store } = useDiary();
  const settings: SettingsData = store.settings ?? { displayName: '', appearance: 'system', writingFont: 'newYork', createdAt: Date.now() };
  const update = (patch: Partial<SettingsData>) => store.put('settings', { ...settings, ...patch }, SETTINGS_ID);
  return [settings, update] as const;
}

function Root({ active }: { active?: ProfilePage }) {
  const { store, me, navigate } = useDiary();
  const [settings] = useSettings();
  const [query, setQuery] = useState('');
  const [editing, setEditing] = useState(false);
  useEffect(() => { if (new URLSearchParams(location.search).get('edit') === '1') setEditing(true); }, []);

  const stats = useMemo(() => {
    const entries = store.entries();
    const photos = entries.reduce((n, e) => n + store.photosOf(e.id).length, 0);
    const days = new Set(entries.map((e) => e.data.dayKey)).size;
    const done = store.tasks().filter((t) => t.data.isCompleted).length;
    const first = entries.map((e) => e.data.dayKey).sort()[0];
    return { entries: entries.length, photos, days, done, first };
  }, [store.revision]);
  const tiles: [string, number, string][] = [['Pages', stats.entries, '/app/journal'], ['Days written on', stats.days, '/app'], ['Photos', stats.photos, '/app/journal'], ['Tasks done', stats.done, '/app/todo']];
  const results = searchSettings(query, !!me.canInvite);
  const trash = Object.values(store.trashed()).reduce((n, l) => n + l.length, 0);
  const detailOf = (p: ProfilePage) => (p === 'categories' ? String(store.categories().length) : p === 'data' && trash > 0 ? `${trash} deleted` : undefined);

  return (
    <>
      <div className="page-title"><h1 className="title1">Profile</h1></div>
      <label className="settings-search glass">
        <Icon name="search" small />
        <span className="sr-only">Search settings</span>
        <input type="search" placeholder="Search settings" value={query} onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Escape' && query) { e.stopPropagation(); setQuery(''); } }} />
      </label>
      {query.trim() ? (
        results.length === 0 ? <p className="callout ink2" style={{ textAlign: 'center', marginTop: 24 }}>No settings match “{query.trim()}”.</p> : (
          <div className="group glass" aria-label="Matching settings" role="group">
            {results.map((s) => (
              <button key={`${s.page}|${s.title}`} className="row" onClick={() => { setQuery(''); s.page === 'profile' ? setEditing(true) : navigate(`/app/profile/${s.page}`); }}>
                <span className="grow">{s.title}<small className="ink3" style={{ display: 'block', fontSize: 13 }}>{s.page === 'profile' ? 'Edit profile' : PAGE_TITLES[s.page]}</small></span>
                <Icon name="chevronRight" small />
              </button>
            ))}
          </div>
        )
      ) : (
        <>
          <section className="profile-card glass">
            <button type="button" className="avatar-button" onClick={() => setEditing(true)} aria-label="Profile picture. Edit profile">
              <Avatar settings={settings} fallback={settings.displayName || me.email || 'F'} big />
            </button>
            <div style={{ minWidth: 0, flex: 1 }}>
              <p className="headline profile-name">{settings.displayName || <span className="ink3">Add your name</span>}</p>
              <p className="callout ink2">{stats.first ? `Writing since ${new Intl.DateTimeFormat('en-GB', { month: 'long', year: 'numeric' }).format(new Date(`${stats.first}T12:00`))}` : 'Your first page is waiting.'}</p>
            </div>
            <button className="btn small" onClick={() => setEditing(true)}>Edit profile</button>
          </section>
          <div className="stats-row glass" role="group" aria-label="Your archive">
            {tiles.map(([label, value, to]) => (
              <button key={label} onClick={() => navigate(to)}><b>{value.toLocaleString('en-GB')}</b><span>{label}</span></button>
            ))}
          </div>
          {PAGE_GROUPS.map((group, i) => (
            <nav key={i} className="group glass profile-rows" aria-label={i === 0 ? 'Account' : i === 1 ? 'Preferences' : 'Privacy, data and help'}>
              {group.map((p) => (
                <button key={p} className="row" aria-current={active === p ? 'page' : undefined} onClick={() => navigate(`/app/profile/${p}`)}>
                  <Icon name={PAGE_ICONS[p]} /><span className="grow">{PAGE_TITLES[p]}</span>
                  {detailOf(p) && <span className="value">{detailOf(p)}</span>}
                  <Icon name="chevronRight" small />
                </button>
              ))}
            </nav>
          ))}
        </>
      )}
      {editing && <EditProfile onClose={() => setEditing(false)} />}
    </>
  );
}
