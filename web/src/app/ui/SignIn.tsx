import { useEffect, useRef, useState } from 'react';
import { turnstileKey } from '../../config/app.ts';
import { api, ApiError, friendly } from '../lib/api.ts';
import { Gate, rememberSession } from './AppRoot.tsx';
import { AppleLogo, GoogleLogo } from './Icons.tsx';

declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, options: Record<string, unknown>) => string;
      reset: (id?: string) => void;
      remove: (id?: string) => void;
    };
  }
}

/** Sign in (SPEC §11.3): Apple, Google, or an email code behind Turnstile. */
export function SignIn({ error }: { error?: string }) {
  const [step, setStep] = useState<'choose' | 'email' | 'code'>('choose');
  const [email, setEmail] = useState('');
  // Batch J: Apple or Google came back saying a new account needs an invite.
  const asksInvite = /invite_(required|invalid)/.test(location.search);
  const [invite, setInvite] = useState('');
  const withInvite = (href: string) => (asksInvite && invite ? `${href}${href.includes('?') ? '&' : '?'}invite=${encodeURIComponent(invite)}` : href);

  return (
    <Gate>
      {step === 'choose' && (
        <>
          <h1>Your days, kept.</h1>
          <p className="sub">Sign in to read and write your diary in the browser. It's encrypted so only you can read it.</p>
          {error && <p className="error" role="alert">{error}</p>}
          <div style={{ display: 'grid', gap: 10, marginTop: 6 }}>
            {asksInvite && <InviteField value={invite} onChange={setInvite} />}
            <a className="provider apple" href={withInvite('/api/auth/apple/start')} onClick={() => rememberSession(true)}><AppleLogo />Continue with Apple</a>
            <a className="provider" href={withInvite('/api/auth/google/start?platform=web')} onClick={() => rememberSession(true)}><GoogleLogo />Continue with Google</a>
            <div className="or">or</div>
            <button className="provider" onClick={() => setStep('email')}>Continue with email</button>
          </div>
          <p className="fine">By continuing you agree to the <a href="/terms">Terms</a> and <a href="/privacy">Privacy Policy</a>. One cookie keeps you signed in; nothing tracks you.</p>
        </>
      )}
      {step === 'email' && <EmailStep email={email} setEmail={setEmail} onSent={() => setStep('code')} onBack={() => setStep('choose')} />}
      {/* A fresh page load after sign-in: Turnstile's script never shares a page with the diary. */}
      {step === 'code' && <CodeStep email={email} onDone={() => { rememberSession(true); location.replace(location.pathname); }} onBack={() => setStep('email')} />}
    </Gate>
  );
}

let turnstileScript: Promise<void> | null = null;
function loadTurnstile(): Promise<void> {
  turnstileScript ??= new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => { turnstileScript = null; reject(new Error('turnstile')); };
    document.head.append(script);
  });
  return turnstileScript;
}

/** The Turnstile check (SPEC §10.1), loaded only when an email code is about to be sent. */
export function TurnstileBox({ onToken, resetKey }: { onToken: (token: string) => void; resetKey?: number }) {
  const box = useRef<HTMLDivElement>(null);
  const widget = useRef<string | undefined>(undefined);
  const [problem, setProblem] = useState('');
  useEffect(() => {
    let live = true;
    loadTurnstile().then(() => {
      if (!live || !box.current || !window.turnstile) return;
      widget.current = window.turnstile.render(box.current, {
        sitekey: turnstileKey(),
        action: 'email-code',
        theme: document.documentElement.dataset.theme ?? 'auto',
        callback: (t: string) => onToken(t),
        'expired-callback': () => onToken(''),
        'error-callback': () => onToken(''),
      });
    }).catch(() => setProblem("The security check couldn't load. Check your connection, or use Apple or Google."));
    return () => {
      live = false;
      if (widget.current) window.turnstile?.remove(widget.current);
    };
  }, []);
  useEffect(() => {
    if (resetKey && widget.current) window.turnstile?.reset(widget.current);
  }, [resetKey]);
  return (
    <>
      <div className="turnstile" ref={box} />
      {problem && <p className="error" role="alert">{problem}</p>}
    </>
  );
}

function EmailStep({ email, setEmail, onSent, onBack }: { email: string; setEmail: (v: string) => void; onSent: () => void; onBack: () => void }) {
  const [token, setToken] = useState('');
  const [resets, setResets] = useState(0);
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState('');

  async function send(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setProblem('');
    try {
      await api('POST', 'auth/email/start', { email: email.trim(), client: 'web', turnstileToken: token });
      onSent();
    } catch (error) {
      setProblem(friendly(error));
      setResets((n) => n + 1);
      setToken('');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={send} style={{ display: 'grid', gap: 14 }}>
      <h1>Continue with email</h1>
      <p className="sub">We'll send a 6-digit code to sign you in.</p>
      <label className="sr-only" htmlFor="email">Email address</label>
      <input id="email" className="field" type="email" autoComplete="email" inputMode="email" placeholder="you@example.com"
        value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus />
      <TurnstileBox onToken={setToken} resetKey={resets} />
      {problem && <p className="error" role="alert">{problem}</p>}
      <button className="btn primary wide" disabled={busy || !token || !email.includes('@')}>{busy ? 'Sending…' : 'Send code'}</button>
      <button type="button" className="text-btn" onClick={onBack}>Back</button>
    </form>
  );
}

/** An invite code (Batch J), shown only when a sign-in would make a new account. */
function InviteField({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <>
      <label className="sr-only" htmlFor="invite">Invite code</label>
      <input id="invite" className="field code" style={{ letterSpacing: 4, fontSize: 22 }} placeholder="ABCD-EFGH" autoCapitalize="characters"
        autoComplete="off" spellCheck={false} maxLength={9} value={value}
        onChange={(e) => onChange(e.target.value.toUpperCase().replace(/[^0-9A-Z-]/g, ''))} />
    </>
  );
}

function CodeStep({ email, onDone, onBack }: { email: string; onDone: () => void; onBack: () => void }) {
  const [code, setCode] = useState('');
  const [asksInvite, setAsksInvite] = useState(false);
  const [invite, setInvite] = useState('');
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState('');
  const [wait, setWait] = useState(30);
  useEffect(() => {
    if (wait <= 0) return;
    const timer = setTimeout(() => setWait(wait - 1), 1000);
    return () => clearTimeout(timer);
  }, [wait]);

  async function verify(value: string) {
    setBusy(true);
    setProblem('');
    try {
      await api('POST', 'auth/email/verify', { email: email.trim(), code: value, client: 'web', ...(asksInvite ? { invite } : {}) });
      onDone();
    } catch (error) {
      setProblem(friendly(error));
      // A new account needs an invite: the email code is still good, so keep it.
      if (error instanceof ApiError && error.code.startsWith('invite_')) setAsksInvite(true);
      else setCode('');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={(e) => { e.preventDefault(); void verify(code); }} style={{ display: 'grid', gap: 14 }}>
      <h1>Check your email</h1>
      <p className="sub">Enter the 6-digit code we sent to <strong>{email}</strong>.</p>
      <label className="sr-only" htmlFor="code">Six-digit code</label>
      <input id="code" className="field code" inputMode="numeric" autoComplete="one-time-code" maxLength={6} autoFocus value={code} disabled={busy}
        onChange={(e) => {
          const value = e.target.value.replace(/\D/g, '').slice(0, 6);
          setCode(value);
          if (value.length === 6 && !asksInvite) void verify(value);
        }} />
      {asksInvite && <InviteField value={invite} onChange={setInvite} />}
      {problem && <p className="error" role="alert">{problem}</p>}
      <button className="btn primary wide" disabled={busy || code.length !== 6 || (asksInvite && invite.replace(/-/g, '').length !== 8)}>{busy ? 'Checking…' : 'Continue'}</button>
      <button type="button" className="text-btn" disabled={wait > 0} onClick={onBack}>
        {wait > 0 ? `Send a new code in ${wait} s` : 'Send a new code'}
      </button>
    </form>
  );
}
