import { useState } from 'react';
import { api, friendly, type Me } from '../../lib/api.ts';
import { forgetBrowser } from '../../lib/trust.ts';
import { Gate } from '../AppRoot.tsx';
import { AppleLogo, GoogleLogo } from '../Icons.tsx';
import { TurnstileBox } from '../SignIn.tsx';

/**
 * Delete account on the web (SPEC §10.6, at /app/settings/account): explain → sign in again
 * (Apple/Google come back here with ?reauth=1) → type DELETE → delete. It runs as its own
 * page that never unlocks the diary, so Turnstile's script never shares a page with
 * decrypted content (/vibesec, DECISIONS 196).
 */
export default function DeleteAccount({ me, onSignOut }: { me: Me; onSignOut: () => void }) {
  const params = new URLSearchParams(location.search);
  const [step, setStep] = useState<'explain' | 'reauth' | 'code' | 'confirm' | 'done'>(params.get('reauth') === '1' ? 'confirm' : 'explain');
  const [problem, setProblem] = useState(params.get('error') === 'reauth' ? "That sign-in was for a different account. Use the one you're signed in with." : '');
  const [token, setToken] = useState('');
  const [resets, setResets] = useState(0);
  const [code, setCode] = useState('');
  const [typed, setTyped] = useState('');
  const [busy, setBusy] = useState(false);
  const email = me.email ?? '';

  async function sendCode() {
    setBusy(true);
    setProblem('');
    try {
      await api('POST', 'auth/email/start', { email, client: 'web', turnstileToken: token });
      setStep('code');
    } catch (error) {
      // A Turnstile token works once; get a fresh one for the next try.
      setProblem(friendly(error));
      setToken('');
      setResets((n) => n + 1);
    } finally { setBusy(false); }
  }

  async function verify(value: string) {
    setBusy(true);
    setProblem('');
    try {
      await api('POST', 'auth/email/verify', { email, code: value, client: 'web', reauth: true });
      setStep('confirm');
    } catch (error) { setProblem(friendly(error)); setCode(''); } finally { setBusy(false); }
  }

  async function remove() {
    setBusy(true);
    setProblem('');
    try {
      await api('POST', 'account/delete', { confirm: 'DELETE' });
      await forgetBrowser();
      setStep('done');
    } catch (error) {
      setProblem(friendly(error));
      if (String((error as { code?: string }).code) === 'reauth_required') setStep('reauth');
    } finally { setBusy(false); }
  }

  return (
    <Gate>
      <h1>Delete account</h1>
      <section style={{ display: 'grid', gap: 14, textAlign: 'left' }}>
        {step === 'explain' && (
          <>
            <p>This permanently deletes your account and every entry, photo and task stored on our servers. This can't be undone.</p>
            <p className="callout ink2">Copies on your iPhone stay there; the app asks what to do with them.</p>
            <button className="btn solid-danger" onClick={() => setStep('reauth')}>Continue</button>
          </>
        )}
        {step === 'reauth' && (
          <>
            <p>To make sure it's you, sign in again.</p>
            {me.providers.includes('apple') && <a className="provider apple" href="/api/auth/apple/start?reauth=1"><AppleLogo />Continue with Apple</a>}
            {me.providers.includes('google') && <a className="provider" href="/api/auth/google/start?platform=web&reauth=1"><GoogleLogo />Continue with Google</a>}
            {me.providers.includes('email') && email && (
              <>
                <p className="callout ink2">Or get a code at {email}.</p>
                <TurnstileBox onToken={setToken} resetKey={resets} />
                <button className="btn" disabled={!token || busy} onClick={() => void sendCode()}>{busy ? 'Sending…' : 'Email me a code'}</button>
              </>
            )}
          </>
        )}
        {step === 'code' && (
          <>
            <label htmlFor="del-code">Enter the 6-digit code we sent to {email}.</label>
            <input id="del-code" className="field code" inputMode="numeric" autoComplete="one-time-code" maxLength={6} autoFocus value={code} disabled={busy}
              onChange={(e) => { const v = e.target.value.replace(/\D/g, '').slice(0, 6); setCode(v); if (v.length === 6) void verify(v); }} />
          </>
        )}
        {step === 'confirm' && (
          <>
            <label htmlFor="del-confirm">Type <strong>DELETE</strong> to delete your account.</label>
            <input id="del-confirm" className="field" autoFocus autoComplete="off" autoCapitalize="characters" value={typed} onChange={(e) => setTyped(e.target.value)} />
            <button className="btn solid-danger" disabled={typed !== 'DELETE' || busy} onClick={() => void remove()}>{busy ? 'Deleting…' : 'Delete my account'}</button>
          </>
        )}
        {step === 'done' && (
          <>
            <p className="headline">Your account is deleted.</p>
            <p className="callout ink2">Everything on our servers is being removed now; it finishes within minutes. We've emailed you a confirmation.</p>
            <button className="btn primary" onClick={onSignOut}>Done</button>
          </>
        )}
        {problem && <p className="error" role="alert">{problem}</p>}
      </section>
      {step !== 'done' && <a className="text-btn" href="/app/profile" style={{ textAlign: 'center' }}>Cancel — keep my account</a>}
    </Gate>
  );
}
