import { lazy, Suspense, useEffect, useMemo, useState } from 'react';
import { SETTINGS_ID, type SettingsData } from '../../lib/payloads.ts';
import { forgetBrowser, isTrusted } from '../../lib/trust.ts';
import { Avatar, AvatarGrid } from '../Avatar.tsx';
import { Modal } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { InstallHelp } from './InstallHelp.tsx';
import { exportDiary, save } from '../../lib/export.ts';
import { SYNC_TEXT } from '../Shell.tsx';

const Devices = lazy(() => import('./Devices.tsx'));
const Invites = lazy(() => import('./Invites.tsx'));
const Categories = lazy(() => import('./Categories.tsx'));
const RecentlyDeleted = lazy(() => import('./RecentlyDeleted.tsx'));
const PrintBook = lazy(() => import('./PrintBook.tsx'));

/** Profile (SPEC §6.9) and its screens, by route. */
export default function ProfileView() {
  const { route } = useDiary();
  const path = route.split('?')[0];
  return (
    <div className="scroll">
      <div className="page" style={{ maxWidth: 720 }}>
        <Suspense fallback={null}>
          {path === '/app/profile/devices' ? <Devices /> : path === '/app/profile/invites' ? <Invites /> : path === '/app/profile/categories' ? <Categories />
            : path === '/app/profile/deleted' ? <RecentlyDeleted /> : <Main />}
        </Suspense>
      </div>
    </div>
  );
}

export function Back({ title }: { title: string }) {
  const { navigate } = useDiary();
  return (
    <div className="page-title" style={{ justifyContent: 'flex-start' }}>
      <button className="icon-btn" aria-label="Back to Profile" onClick={() => navigate('/app/profile')}><Icon name="chevronLeft" /></button>
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

function Main() {
  const { store, engine, me, navigate, signOut, key, showHelp, toast } = useDiary();
  const [printing, setPrinting] = useState(false);
  const [exporting, setExporting] = useState<string | null>(null);
  const [withTrash, setWithTrash] = useState(false);
  const [settings, update] = useSettings();
  const [name, setName] = useState(settings.displayName);
  const [trusted, setTrusted] = useState<{ expiresAt: number } | null>(null);
  const [confirmSignOut, setConfirmSignOut] = useState(false);
  const [picking, setPicking] = useState(false);
  const [installing, setInstalling] = useState(false);
  useEffect(() => { void isTrusted().then(setTrusted); }, []);
  useEffect(() => setName(settings.displayName), [settings.displayName]);

  const stats = useMemo(() => {
    const entries = store.entries();
    const photos = entries.reduce((n, e) => n + store.photosOf(e.id).length, 0);
    const days = new Set(entries.map((e) => e.data.dayKey)).size;
    const done = store.tasks().filter((t) => t.data.isCompleted).length;
    const first = entries.map((e) => e.data.dayKey).sort()[0];
    return { entries: entries.length, photos, days, done, first };
  }, [store.revision]);
  const tiles: [string, number, string][] = [['Entries', stats.entries, '/app/journal'], ['Photos', stats.photos, '/app/journal'], ['Days written on', stats.days, '/app'], ['Tasks done', stats.done, '/app/todo']];
  const showTiles = (() => { try { return localStorage.getItem('folio.photoTiles') !== 'off'; } catch { return true; } })();
  const provider = me.providers.includes('apple') ? 'Apple' : me.providers.includes('google') ? 'Google' : 'Email';

  return (
    <>
      <div className="page-title"><h1 className="title1">Profile</h1></div>
      <section className="header-card glass">
        <button type="button" className="avatar-button" onClick={() => setPicking((v) => !v)} aria-expanded={picking} aria-label="Profile picture">
          <Avatar settings={settings} fallback={settings.displayName || me.email || 'F'} big />
        </button>
        <div className="grow" style={{ minWidth: 0, flex: 1 }}>
          <label className="sr-only" htmlFor="name">Your name</label>
          <input id="name" className="title-input" style={{ padding: 0 }} placeholder="Your name" maxLength={40} value={name}
            onChange={(e) => setName(e.target.value)} onBlur={() => name !== settings.displayName && update({ displayName: name.trim() })}
            onKeyDown={(e) => e.key === 'Enter' && (e.target as HTMLInputElement).blur()} />
          <p className="callout ink2">
            {stats.first ? `Writing since ${new Intl.DateTimeFormat('en-GB', { month: 'long', year: 'numeric' }).format(new Date(`${stats.first}T12:00`))} · ` : ''}
            {stats.entries} {stats.entries === 1 ? 'page' : 'pages'}
          </p>
        </div>
      </section>
      {picking && (
        <section className="glass avatar-panel">
          <p className="caption ink2">Folio avatars · choose a photo in the iPhone app</p>
          <AvatarGrid current={settings.avatar} onPick={(key) => { update({ avatar: key, avatarPhoto: undefined }); setPicking(false); }} />
          {settings.avatar && <button type="button" className="btn small" onClick={() => { update({ avatar: undefined, avatarPhoto: undefined }); setPicking(false); }}>Remove picture</button>}
        </section>
      )}
      <div className="tiles">
        {tiles.map(([label, value, to]) => (
          <button key={label} className="tile glass" onClick={() => navigate(to)}><b>{value.toLocaleString('en-GB')}</b><span className="callout ink2">{label}</span></button>
        ))}
      </div>

      <h2 className="caption ink3 group-label">Account</h2>
      <div className="group glass">
        <div className="row"><Icon name={provider === 'Email' ? 'pages' : 'profile'} /><span className="grow">{me.email ?? 'Signed in'}</span><span className="value">{provider}</span></div>
        <div className="row">
          <Icon name="sync" /><span className="grow">{SYNC_TEXT[engine.status]}
            {engine.lastSynced && <small className="ink3" style={{ display: 'block', fontSize: 13 }}>Last synced {new Intl.DateTimeFormat('en-GB', { timeStyle: 'short' }).format(engine.lastSynced)}</small>}
          </span>
          <button className="btn small" onClick={() => engine.syncNow()}>Sync now</button>
        </div>
        <button className="row" onClick={() => navigate('/app/profile/devices')}><Icon name="devices" /><span className="grow">Devices</span><Icon name="chevronRight" small /></button>
        <button className="row" onClick={() => setInstalling(true)}><Icon name="iphone" /><span className="grow">Install on your phone</span><Icon name="chevronRight" small /></button>
        {installing && <InstallHelp onClose={() => setInstalling(false)} />}
        {me.canInvite && <button className="row" onClick={() => navigate('/app/profile/invites')}><Icon name="plus" /><span className="grow">Invite a friend</span><Icon name="chevronRight" small /></button>}
        <div className="row">
          <Icon name="lock" />
          <span className="grow">{trusted ? 'This browser is trusted' : 'This browser unlocks each visit'}
            {trusted && <small className="ink3" style={{ display: 'block', fontSize: 13 }}>Until {new Intl.DateTimeFormat('en-GB', { dateStyle: 'medium' }).format(trusted.expiresAt)}</small>}
          </span>
          {trusted && <button className="btn small" onClick={() => void forgetBrowser().then(() => setTrusted(null))}>Forget</button>}
        </div>
        <button className="row" onClick={() => setConfirmSignOut(true)}><Icon name="signout" /><span className="grow">Sign out</span></button>
        <button className="row danger" onClick={() => location.assign('/app/settings/account')}><Icon name="trash" /><span className="grow">Delete account</span><Icon name="chevronRight" small /></button>
      </div>

      <h2 className="caption ink3 group-label">Categories</h2>
      <div className="group glass">
        <button className="row" onClick={() => navigate('/app/profile/categories')}><Icon name="tag" /><span className="grow">Categories</span><span className="value">{store.categories().length}</span><Icon name="chevronRight" small /></button>
      </div>

      <h2 className="caption ink3 group-label">Appearance</h2>
      <div className="group glass">
        <label className="row"><Icon name="sun" /><span className="grow">Theme</span>
          <select value={settings.appearance} onChange={(e) => update({ appearance: e.target.value })}>
            <option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option>
          </select>
        </label>
        <label className="row"><Icon name="textformat" /><span className="grow">Writing font</span>
          <select value={settings.writingFont} onChange={(e) => update({ writingFont: e.target.value })}>
            <option value="newYork">New York</option><option value="sfPro">SF Pro</option>
          </select>
        </label>
        <label className="row"><Icon name="calendar" /><span className="grow">First day of week</span>
          <select value={settings.firstWeekday ?? ''} onChange={(e) => update({ firstWeekday: e.target.value ? Number(e.target.value) : undefined })}>
            <option value="">System</option><option value="2">Monday</option><option value="1">Sunday</option><option value="7">Saturday</option>
          </select>
        </label>
      </div>

      <h2 className="caption ink3 group-label">Writing</h2>
      <div className="group glass">
        <label className="row"><Icon name="tag" /><span className="grow">Default category</span>
          <select value={settings.defaultCategoryID ?? ''} onChange={(e) => update({ defaultCategoryID: e.target.value || undefined })}>
            <option value="">None</option>
            {store.categories().map((c) => <option key={c.id} value={c.id}>{c.data.name}</option>)}
          </select>
        </label>
        <label className="row"><Icon name="photo" /><span className="grow">Show photo tiles on calendar</span>
          <input type="checkbox" className="toggle" defaultChecked={showTiles} onChange={(e) => { try { localStorage.setItem('folio.photoTiles', e.target.checked ? 'on' : 'off'); } catch { /* */ } store.emit(); }} />
        </label>
      </div>

      <h2 className="caption ink3 group-label">Dictation & Intelligence</h2>
      <div className="group glass">
        <div className="row"><Icon name="mic" /><span className="grow">Dictation and ✦ writing tools</span><span className="value">Available in the iPhone app</span></div>
      </div>

      <h2 className="caption ink3 group-label">Your data</h2>
      <div className="group glass">
        <button className="row" onClick={() => navigate('/app/profile/deleted')}><Icon name="trash" /><span className="grow">Recently Deleted</span><span className="value">{Object.values(store.trashed()).reduce((n, l) => n + l.length, 0)}</span><Icon name="chevronRight" small /></button>
        <button className="row" disabled={!!exporting} onClick={async () => {
          setExporting('Starting…');
          try {
            const blob = await exportDiary(store, key, withTrash, (done, total) => setExporting(`Photos ${done} of ${total}`));
            save(blob, `Folio Export ${new Date().toISOString().slice(0, 10)}.zip`);
          } catch { toast("Couldn't make the export. Please try again."); }
          setExporting(null);
        }}><Icon name="export" /><span className="grow">Export as JSON + photos<small className="ink3" style={{ display: 'block', fontSize: 13 }}>{exporting ?? 'A zip made in this browser, decrypted. Nothing is uploaded.'}</small></span><Icon name="download" small /></button>
        <label className="row"><span className="grow" style={{ paddingLeft: 34 }}>Include Recently Deleted</span><input type="checkbox" className="toggle" checked={withTrash} onChange={(e) => setWithTrash(e.target.checked)} /></label>
        <button className="row" onClick={() => setPrinting(true)}><Icon name="journal" /><span className="grow">Export PDF<small className="ink3" style={{ display: 'block', fontSize: 13 }}>A book of your pages, through your browser's print window</small></span><Icon name="chevronRight" small /></button>
      </div>
      {printing && <Suspense fallback={null}><PrintBook onClose={() => setPrinting(false)} /></Suspense>}

      <h2 className="caption ink3 group-label">Help</h2>
      <div className="group glass">
        <button className="row" onClick={() => showHelp('marks')}><Icon name="help" /><span className="grow">What do the marks mean?</span><Icon name="chevronRight" small /></button>
        <button className="row" onClick={() => showHelp('shortcuts')}><Icon name="keyboard" /><span className="grow">Keyboard shortcuts</span><span className="value">?</span></button>
        <button className="row" onClick={() => { try { localStorage.removeItem(`folio.welcomed.${me.userId}`); } catch { /* */ } location.reload(); }}><Icon name="sparkle" /><span className="grow">Show the welcome again</span><Icon name="chevronRight" small /></button>
        <a className="row" href="/support" style={{ color: 'inherit', textDecoration: 'none' }}><Icon name="info" /><span className="grow">Support & FAQ</span><Icon name="chevronRight" small /></a>
        <a className="row" href="mailto:support@devilsense.com" style={{ color: 'inherit', textDecoration: 'none' }}><Icon name="mail" /><span className="grow">Contact support</span><span className="value">support@devilsense.com</span></a>
      </div>

      <h2 className="caption ink3 group-label">About</h2>
      <div className="group glass">
        {([['/', 'Website'], ['/privacy', 'Privacy Policy'], ['/terms', 'Terms of Use'], ['/cookies', 'Cookies and storage'], ['/acceptable-use', 'Acceptable use'],
          ['/accessibility', 'Accessibility'], ['/imprint', 'Company details'], ['/open-source', 'Open source']] as const).map(([href, label]) => (
          <a key={href} className="row" href={href} style={{ color: 'inherit', textDecoration: 'none' }}><span className="grow">{label}</span><Icon name="chevronRight" small /></a>
        ))}
      </div>
      <p className="fine" style={{ textAlign: 'center' }}>Folio for the web · Made by Soul Archive Ltd, registered in England and Wales (no. 16186654) · © 2026</p>

      {confirmSignOut && (
        <Modal title="Sign out of Folio here?" message="Your diary stays in your account and on your other devices. This browser forgets it." onClose={() => setConfirmSignOut(false)}>
          <button className="btn" onClick={() => setConfirmSignOut(false)}>Cancel</button>
          <button className="btn solid-danger" onClick={() => void signOut()}>Sign out</button>
        </Modal>
      )}
    </>
  );
}
