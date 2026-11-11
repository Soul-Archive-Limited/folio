import { lazy, Suspense, useEffect, useState } from 'react';
import { site } from '../../../config/site.ts';
import { exportDiary, save } from '../../lib/export.ts';
import { PAGE_TITLES, type ProfilePage } from '../../lib/profile-search.ts';
import { forgetBrowser, isTrusted } from '../../lib/trust.ts';
import { celebrationsOn, setCelebrations } from '../celebrate.ts';
import { Modal } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { SYNC_TEXT } from '../Shell.tsx';
import { InstallHelp } from './InstallHelp.tsx';
import { Back, useSettings } from './ProfileView.tsx';

const Categories = lazy(() => import('./Categories.tsx'));
const PrintBook = lazy(() => import('./PrintBook.tsx'));

/** One Profile page (Batch N), as on the iPhone. */
export function PageContent({ page }: { page: ProfilePage }) {
  if (page === 'categories') return <Suspense fallback={null}><Categories /></Suspense>;
  return (
    <>
      <Back title={PAGE_TITLES[page]} />
      {page === 'account' ? <Account /> : page === 'appearance' ? <Appearance /> : page === 'writing' ? <Writing />
        : page === 'notifications' ? <IPhoneOnlyPage icon="memories" text="Task reminders and the On this day note are set on your iPhone. Each device schedules its own, in its own time zone; nothing goes through a server." />
        : page === 'widgets' ? <IPhoneOnlyPage icon="widgets" text="Widgets live on your iPhone's Home Screen and Lock Screen. Choose what they show in the iPhone app: Profile → Widgets." />
        : page === 'privacy' ? <Privacy /> : page === 'data' ? <Data /> : <Help />}
    </>
  );
}

function IPhoneOnlyPage({ icon, text }: { icon: string; text: string }) {
  return (
    <div className="group glass">
      <div className="row"><Icon name={icon} /><span className="grow">{text}</span></div>
    </div>
  );
}

function Account() {
  const { engine, me, navigate, signOut } = useDiary();
  const [installing, setInstalling] = useState(false);
  const [confirmSignOut, setConfirmSignOut] = useState(false);
  const provider = me.providers.includes('apple') ? 'Apple' : me.providers.includes('google') ? 'Google' : 'Email';
  return (
    <>
      <div className="group glass">
        <div className="row"><Icon name={provider === 'Email' ? 'pages' : 'profile'} /><span className="grow">{me.email ?? 'Signed in'}</span><span className="value">{provider}</span></div>
        <div className="row">
          <Icon name="sync" /><span className="grow">{SYNC_TEXT[engine.status]}
            {engine.lastSynced && <small className="ink3" style={{ display: 'block', fontSize: 13 }}>Last synced {new Intl.DateTimeFormat('en-GB', { timeStyle: 'short' }).format(engine.lastSynced)}</small>}
          </span>
          <button className="btn small" onClick={() => engine.syncNow()}>Sync now</button>
        </div>
        <button className="row" onClick={() => navigate('/app/profile/devices')}><Icon name="devices" /><span className="grow">Devices</span><Icon name="chevronRight" small /></button>
        {me.canInvite && <button className="row" onClick={() => navigate('/app/profile/invites')}><Icon name="invite" /><span className="grow">Invite a friend</span><Icon name="chevronRight" small /></button>}
        <button className="row" onClick={() => setInstalling(true)}><Icon name="iphone" /><span className="grow">Install on your phone</span><Icon name="chevronRight" small /></button>
        {installing && <InstallHelp onClose={() => setInstalling(false)} />}
        <button className="row" onClick={() => setConfirmSignOut(true)}><Icon name="signout" /><span className="grow">Sign out</span></button>
        <button className="row danger" onClick={() => location.assign('/app/settings/account')}><Icon name="trash" /><span className="grow">Delete account</span><Icon name="chevronRight" small /></button>
      </div>
      {confirmSignOut && (
        <Modal title="Sign out of Folio here?" message="Your diary stays in your account and on your other devices. This browser forgets it." onClose={() => setConfirmSignOut(false)}>
          <button className="btn" onClick={() => setConfirmSignOut(false)}>Cancel</button>
          <button className="btn solid-danger" onClick={() => void signOut()}>Sign out</button>
        </Modal>
      )}
    </>
  );
}

function Appearance() {
  const [settings, update] = useSettings();
  const [celebrate, setCelebrate] = useState(celebrationsOn());
  return (
    <>
      <div className="group glass">
        <label className="row"><Icon name="appearance" /><span className="grow">Theme</span>
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
        <label className="row"><Icon name="sparkle" /><span className="grow">Celebrations</span>
          <input type="checkbox" className="toggle" checked={celebrate} onChange={(e) => { setCelebrations(e.target.checked); setCelebrate(e.target.checked); }} />
        </label>
      </div>
      <p className="group-foot">Celebrations are small, quiet moments when you keep a day's page or finish a day's tasks — no streaks, no counters. With reduced motion they're a simple fade. Kept in this browser.</p>
    </>
  );
}

function Writing() {
  const { store } = useDiary();
  const [settings, update] = useSettings();
  const showTiles = (() => { try { return localStorage.getItem('folio.photoTiles') !== 'off'; } catch { return true; } })();
  return (
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
      <div className="row"><Icon name="mic" /><span className="grow">Dictation and ✦ writing tools</span><span className="value">In the iPhone app</span></div>
    </div>
  );
}

function Privacy() {
  const [trusted, setTrusted] = useState<{ expiresAt: number } | null>(null);
  useEffect(() => { void isTrusted().then(setTrusted); }, []);
  return (
    <>
      <div className="group glass">
        <div className="row">
          <Icon name="lock" />
          <span className="grow">{trusted ? 'This browser is trusted' : 'This browser unlocks each visit'}
            {trusted && <small className="ink3" style={{ display: 'block', fontSize: 13 }}>Until {new Intl.DateTimeFormat('en-GB', { dateStyle: 'medium' }).format(trusted.expiresAt)}</small>}
          </span>
          {trusted && <button className="btn small" onClick={() => void forgetBrowser().then(() => setTrusted(null))}>Forget</button>}
        </div>
        <div className="row"><Icon name="lock" /><span className="grow">Lock Folio with Face ID</span><span className="value">In the iPhone app</span></div>
      </div>
      <p className="group-foot">Your diary is decrypted only in this tab's memory, or kept encrypted in this browser if you trusted it.</p>
    </>
  );
}

function Data() {
  const { store, key, navigate, toast } = useDiary();
  const [printing, setPrinting] = useState(false);
  const [exporting, setExporting] = useState<string | null>(null);
  const [withTrash, setWithTrash] = useState(false);
  return (
    <>
      <div className="group glass">
        <button className="row" onClick={() => navigate('/app/profile/deleted')}><Icon name="trash" /><span className="grow">Recently Deleted</span><span className="value">{Object.values(store.trashed()).reduce((n, l) => n + l.length, 0)}</span><Icon name="chevronRight" small /></button>
        <button className="row" disabled={!!exporting} onClick={async () => {
          setExporting('Starting…');
          try {
            const { blob, missing } = await exportDiary(store, key, withTrash, (done, total) => setExporting(`Photos ${done} of ${total}`));
            save(blob, `Folio Export ${new Date().toISOString().slice(0, 10)}.zip`);
            if (missing > 0) toast(`${missing} ${missing === 1 ? 'photo' : 'photos'} couldn't be downloaded, so the export is missing them. Check your connection and export again.`, undefined, 10);
          } catch { toast("Couldn't make the export. Please try again."); }
          setExporting(null);
        }}><Icon name="export" /><span className="grow">Export as JSON + photos<small className="ink3" style={{ display: 'block', fontSize: 13 }}>{exporting ?? 'A zip made in this browser, decrypted. Nothing is uploaded.'}</small></span><Icon name="download" small /></button>
        <label className="row"><span className="grow" style={{ paddingLeft: 34 }}>Include Recently Deleted</span><input type="checkbox" className="toggle" checked={withTrash} onChange={(e) => setWithTrash(e.target.checked)} /></label>
        <button className="row" onClick={() => setPrinting(true)}><Icon name="journal" /><span className="grow">Export PDF<small className="ink3" style={{ display: 'block', fontSize: 13 }}>A book of your pages, through your browser's print window</small></span><Icon name="chevronRight" small /></button>
      </div>
      <p className="group-foot">Deleted items stay in Recently Deleted for 30 days. To erase a device's copy, use that device; to remove everything, delete your account (Account &amp; Sync).</p>
      {printing && <Suspense fallback={null}><PrintBook onClose={() => setPrinting(false)} /></Suspense>}
    </>
  );
}

function Help() {
  const { me, showHelp } = useDiary();
  const version = '0.1.0 · web';
  return (
    <>
      <div className="group glass">
        <button className="row" onClick={() => showHelp('marks')}><Icon name="help" /><span className="grow">What do the marks mean?</span><Icon name="chevronRight" small /></button>
        <button className="row" onClick={() => showHelp('shortcuts')}><Icon name="keyboard" /><span className="grow">Keyboard shortcuts</span><span className="value">?</span></button>
        <button className="row" onClick={() => { try { localStorage.removeItem(`folio.welcomed.${me.userId}`); } catch { /* */ } location.reload(); }}><Icon name="sparkle" /><span className="grow">Show the welcome again</span><Icon name="chevronRight" small /></button>
        <a className="row" href="/support" style={{ color: 'inherit', textDecoration: 'none' }}><Icon name="info" /><span className="grow">Support & FAQ</span><Icon name="chevronRight" small /></a>
        <a className="row" href="mailto:support@devilsense.com" style={{ color: 'inherit', textDecoration: 'none' }}><Icon name="mail" /><span className="grow">Contact support</span><span className="value">support@devilsense.com</span></a>
      </div>
      <h2 className="caption ink3 group-label">Legal</h2>
      <div className="group glass">
        {([['/', 'Website'], ['/privacy', 'Privacy Policy'], ['/terms', 'Terms of Use'], ['/cookies', 'Cookies and storage'], ['/acceptable-use', 'Acceptable use'],
          ['/accessibility', 'Accessibility'], ['/imprint', 'Company details'], ['/open-source', 'Open source']] as const).map(([href, label]) => (
          <a key={href} className="row" href={href} style={{ color: 'inherit', textDecoration: 'none' }}><span className="grow">{label}</span><Icon name="chevronRight" small /></a>
        ))}
      </div>
      <div className="group glass">
        <div className="row"><Icon name="info" /><span className="grow">Version</span><span className="value">{version}</span></div>
      </div>
      <p className="fine" style={{ textAlign: 'center' }}>Folio for the web · Made by {site.company.name}, registered in England and Wales (no. {site.company.number}), {site.company.office} · © 2026</p>
    </>
  );
}
