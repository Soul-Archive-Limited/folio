import { lazy, Suspense, useEffect, useState } from 'react';
import { api, ApiError, type Me } from '../lib/api.ts';
import { importDataKey, type DataKey } from '../lib/crypto.ts';
import { forgetBrowser, trustBrowser, trustedKey } from '../lib/trust.ts';
import { Mark } from './Icons.tsx';
import { SignIn } from './SignIn.tsx';

const Unlock = lazy(() => import('./Unlock.tsx'));
const SetupKey = lazy(() => import('./SetupKey.tsx'));
const Shell = lazy(() => import('./Shell.tsx'));
const DeleteAccount = lazy(() => import('./profile/DeleteAccount.tsx'));

type Phase =
  | { kind: 'loading' }
  | { kind: 'signedOut'; error?: string }
  | { kind: 'offline' }
  | { kind: 'setupKey'; me: Me }
  | { kind: 'locked'; me: Me }
  | { kind: 'deleting'; me: Me }
  | { kind: 'ready'; me: Me; key: DataKey };

const SIGN_IN_ERRORS: Record<string, string> = {
  cancelled: 'Sign-in was cancelled.',
  failed: "Sign-in didn't work. Please try again.",
};

/**
 * The web app (SPEC §11.3): sign in → unlock (or create the recovery key for a brand-new
 * account) → the diary. Nothing from the diary exists until the Data Key is in memory.
 */
export default function AppRoot() {
  const [phase, setPhase] = useState<Phase>({ kind: 'loading' });

  async function boot() {
    try {
      const { signedIn: yes } = await api<{ signedIn: boolean }>('GET', 'auth/session');
      if (!yes) throw new ApiError(401, 'unauthorized');
      await signedIn(await api<Me>('GET', 'account/me'));
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        const code = new URLSearchParams(location.search).get('error');
        setPhase({ kind: 'signedOut', error: code ? SIGN_IN_ERRORS[code] : undefined });
      } else {
        setPhase({ kind: 'offline' });
      }
    }
  }

  async function signedIn(me: Me) {
    void reportBrowserName(me.sessionId);
    // Deleting the account needs no key, so that page never unlocks the diary.
    if (location.pathname.startsWith('/app/settings/account')) return setPhase({ kind: 'deleting', me });
    const key = await trustedKey(me.userId);
    if (key) setPhase({ kind: 'ready', me, key });
    else setPhase(me.hasRecoveryKey ? { kind: 'locked', me } : { kind: 'setupKey', me });
  }

  async function unlocked(me: Me, raw: Uint8Array, trust: boolean) {
    if (trust) await trustBrowser(me.userId, raw);
    const key = await importDataKey(raw);
    raw.fill(0);
    setPhase({ kind: 'ready', me, key });
  }

  async function signOut() {
    try { await api('POST', 'auth/sign-out', {}); } catch { /* the session ends here either way */ }
    await forgetBrowser();
    history.replaceState(null, '', '/app');
    setPhase({ kind: 'signedOut' });
  }

  useEffect(() => { void boot(); }, []);

  const fallback = <Splash />;
  switch (phase.kind) {
    case 'loading': return fallback;
    case 'offline':
      return (
        <Gate>
          <h1>You're offline</h1>
          <p className="sub">Folio needs a connection to open your diary in the browser.</p>
          <button className="btn primary wide" onClick={() => { setPhase({ kind: 'loading' }); void boot(); }}>Try again</button>
        </Gate>
      );
    case 'signedOut': return <SignIn error={phase.error} />;
    case 'setupKey': return <Suspense fallback={fallback}><SetupKey me={phase.me} onDone={(raw, trust) => unlocked(phase.me, raw, trust)} onExists={() => setPhase({ kind: 'locked', me: phase.me })} onSignOut={signOut} /></Suspense>;
    case 'deleting': return <Suspense fallback={fallback}><DeleteAccount me={phase.me} onSignOut={signOut} /></Suspense>;
    case 'locked': return <Suspense fallback={fallback}><Unlock me={phase.me} onUnlocked={(raw, trust) => unlocked(phase.me, raw, trust)} onSignOut={signOut} /></Suspense>;
    case 'ready': return <Suspense fallback={fallback}><Shell me={phase.me} dataKey={phase.key} onSignOut={signOut} onSessionEnded={() => setPhase({ kind: 'signedOut', error: 'You were signed out.' })} /></Suspense>;
  }
}

export function Gate({ children }: { children: React.ReactNode }) {
  return (
    <main className="gate">
      <div className="aura" aria-hidden="true"><i /><i /><i /></div>
      <a className="gate-home" href="/"><Mark />Folio</a>
      <section className="gate-card glass" style={{ position: 'relative' }}>
        <Mark className="mark" />
        {children}
      </section>
      <p className="gate-foot"><a href="/security">How your privacy works</a> · <a href="/support">Help</a></p>
    </main>
  );
}

function Splash() {
  return (
    <main className="gate" aria-busy="true">
      <Mark className="mark" />
      <span className="sr-only">Loading Folio</span>
    </main>
  );
}

/** Devices shows "Brave on macOS" — Brave's User-Agent says Chrome (DECISIONS 189). */
async function reportBrowserName(sessionId: string) {
  const agent = navigator.userAgent;
  const nav = navigator as Navigator & { brave?: unknown; userAgentData?: { platform?: string } };
  const browser = nav.brave ? 'Brave' : /Edg\//.test(agent) ? 'Edge' : /Firefox\//.test(agent) ? 'Firefox' : /Chrome\//.test(agent) ? 'Chrome' : /Safari\//.test(agent) ? 'Safari' : 'Browser';
  const platform = nav.userAgentData?.platform || agent;
  const os = /mac/i.test(platform) && !/iPhone|iPad/.test(agent) ? 'macOS' : /iPhone/.test(agent) ? 'iOS' : /iPad/.test(agent) ? 'iPadOS'
    : /Android/i.test(platform) ? 'Android' : /Win/i.test(platform) ? 'Windows' : /Linux|CrOS/i.test(platform) ? 'Linux' : '';
  const name = os ? `${browser} on ${os}` : browser;
  const marker = `${sessionId}|${name}`;
  try {
    if (localStorage.getItem('folio.device') === marker) return;
    await api('PUT', 'account/device', { name });
    localStorage.setItem('folio.device', marker);
  } catch { /* not important */ }
}
