import { useMemo, useState } from 'react';
import { api, ApiError, friendly, type Me } from '../lib/api.ts';
import { randomBytes } from '../lib/bytes.ts';
import { encodeBase32, recoveryKeyLines } from '../lib/base32.ts';
import { wrapWithRecoveryKey } from '../lib/crypto.ts';
import { Gate } from './AppRoot.tsx';

interface Props { me: Me; onDone: (raw: Uint8Array, trust: boolean) => void; onExists: () => void; onSignOut: () => void }

/**
 * A brand-new account that starts on the web (SPEC §6.13, §10.3): make the Data Key here,
 * show the recovery key, confirm the last 4, then store only the wrapped copy on the server.
 */
export default function SetupKey({ me, onDone, onExists, onSignOut }: Props) {
  const secrets = useMemo(() => ({ dataKey: randomBytes(32), recovery: randomBytes(16) }), []);
  const key = useMemo(() => encodeBase32(secrets.recovery), [secrets]);
  const lines = recoveryKeyLines(key);
  const [typed, setTyped] = useState('');
  const [trust, setTrust] = useState(false);
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState('');
  const confirmed = typed.toUpperCase().replace(/\s/g, '') === key.slice(-4);

  const fileText = `Folio Recovery Key\n\n${lines.join('\n')}\n\nThis key is the only way to read your diary on a new device if your iPhone is lost. We can't recover it for you.\nAccount: ${me.email ?? ''}\n`;

  function download() {
    const url = URL.createObjectURL(new Blob([fileText], { type: 'text/plain' }));
    const a = Object.assign(document.createElement('a'), { href: url, download: 'Folio Recovery Key.txt' });
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function finish() {
    setBusy(true);
    setProblem('');
    try {
      await api('PUT', 'keys/recovery', { envelope: await wrapWithRecoveryKey(secrets.dataKey, secrets.recovery, me.userId) });
      secrets.recovery.fill(0);
      onDone(secrets.dataKey, trust);
    } catch (error) {
      // Another device set the account up a moment ago: unlock with that one instead.
      if (error instanceof ApiError && error.status === 409) onExists();
      else setProblem(friendly(error));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Gate>
      <h1>Your recovery key</h1>
      <p className="sub">This key is the only way to read your diary on a new device if your iPhone is lost. We can't recover it for you.</p>
      <div className="recovery glass" aria-label={`Recovery key: ${key.split('').join(' ')}`}>{lines[0]}<br />{lines[1]}</div>
      <div style={{ display: 'flex', gap: 8, justifyContent: 'center', flexWrap: 'wrap' }}>
        <button className="btn small" onClick={() => void navigator.clipboard.writeText(lines.join('-'))}>Copy</button>
        <button className="btn small" onClick={download}>Save as file</button>
        <button className="btn small" onClick={() => window.print()}>Print</button>
      </div>
      <label className="callout ink2" htmlFor="last4">To make sure you saved it, type the last 4 characters.</label>
      <input id="last4" className="field code" maxLength={4} autoComplete="off" spellCheck={false} placeholder="Last 4" value={typed} onChange={(e) => setTyped(e.target.value)} style={{ width: 180, justifySelf: 'center' }} />
      {typed.length === 4 && !confirmed && <p className="error">That doesn't match the end of your key.</p>}
      <label className="check" style={{ justifySelf: 'center' }}>
        <input type="checkbox" checked={trust} onChange={(e) => setTrust(e.target.checked)} />Trust this browser for 30 days
      </label>
      {problem && <p className="error" role="alert">{problem}</p>}
      <button className="btn primary wide" disabled={!confirmed || busy} onClick={finish}>{busy ? 'Encrypting…' : 'Continue'}</button>
      <button className="text-btn" onClick={onSignOut}>Sign out</button>
    </Gate>
  );
}
