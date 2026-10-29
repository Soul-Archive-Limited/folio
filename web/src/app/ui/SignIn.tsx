import { useEffect, useRef, useState } from 'react';
import { turnstileKey } from '../../config/app.ts';
import { api, friendly } from '../lib/api.ts';
import { Gate } from './AppRoot.tsx';
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
export function SignIn({ error, onSignedIn }: { error?: string; onSignedIn: () => void }) {
  const [step, setStep] = useState<'choose' | 'email' | 'code'>('choose');
  const [email, setEmail] = useState('');

  return (
    <Gate>
      {step === 'choose' && (
        <>
          <h1>Your days, kept.</h1>
          <p className="sub">Sign in to read and write your diary in the browser. It's encrypted so only you can read it.</p>
          {error && <p className="error" role="alert">{error}</p>}
          <div style={{ display: 'grid', gap: 10, marginTop: 6 }}>
            <a className="provider apple" href="/api/auth/apple/start"><AppleLogo />Continue with Apple</a>
            <a className="provider" href="/api/auth/google/start?platform=web"><GoogleLogo />Continue with Google</a>
            <div className="or">or</div>
            <button className="provider" onClick={() => setStep('email')}>Continue with email</button>
          </div>
          <p className="fine">By continuing you agree to the <a href="/terms">Terms</a> and <a href="/privacy">Privacy Policy</a>. One cookie keeps you signed in; nothing tracks you.</p>
        </>
      )}
      {step === 'email' && <EmailStep email={email} setEmail={setEmail} onSent={() => setStep('code')} onBack={() => setStep('choose')} />}
      {step === 'code' && <CodeStep email={email} onDone={onSignedIn} onBack={() => setStep('email')} />}
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

function CodeStep({ email, onDone, onBack }: { email: string; onDone: () => void; onBack: () => void }) {
  const [code, setCode] = useState('');
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
      await api('POST', 'auth/email/verify', { email: email.trim(), code: value, client: 'web' });
      onDone();
    } catch (error) {
      setProblem(friendly(error));
      setCode('');
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
          if (value.length === 6) void verify(value);
        }} />
      {problem && <p className="error" role="alert">{problem}</p>}
      <button className="btn primary wide" disabled={busy || code.length !== 6}>{busy ? 'Checking…' : 'Continue'}</button>
      <button type="button" className="text-btn" disabled={wait > 0} onClick={onBack}>
        {wait > 0 ? `Send a new code in ${wait} s` : 'Send a new code'}
      </button>
    </form>
  );
}
