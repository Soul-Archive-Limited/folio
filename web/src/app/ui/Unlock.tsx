import { useEffect, useMemo, useState } from 'react';
import { encode } from 'uqr';
import { api, ApiError, friendly, type Me } from '../lib/api.ts';
import { toBase64, toBase64Url } from '../lib/bytes.ts';
import { exportPublicKey, receiveLinkedKey, unwrapWithRecoveryKey, WrongRecoveryKey, x25519KeyPair } from '../lib/crypto.ts';
import { Gate } from './AppRoot.tsx';

interface Props { me: Me; onUnlocked: (raw: Uint8Array, trust: boolean) => void; onSignOut: () => void }

/**
 * Unlock (SPEC §10.4, §11.3): "Scan with your iPhone" by default — the iPhone seals the Data
 * Key to this page's X25519 key and the server only relays it — or the recovery key.
 */
export default function Unlock({ me, onUnlocked, onSignOut }: Props) {
  const [mode, setMode] = useState<'qr' | 'recovery'>('qr');
  const [trust, setTrust] = useState(false);
  return (
    <Gate>
      <h1>Unlock your diary</h1>
      <p className="sub">It's encrypted. Your iPhone can pass this browser the key, or you can use your recovery key.</p>
      <div className="segmented glass" role="group" aria-label="How to unlock" style={{ justifySelf: 'center' }}>
        <button aria-pressed={mode === 'qr'} onClick={() => setMode('qr')}>Scan with your iPhone</button>
        <button aria-pressed={mode === 'recovery'} onClick={() => setMode('recovery')}>Use recovery key</button>
      </div>
      {mode === 'qr' ? <QRUnlock me={me} onKey={(raw) => onUnlocked(raw, trust)} /> : <RecoveryUnlock me={me} onKey={(raw) => onUnlocked(raw, trust)} />}
      <label className="check" style={{ justifySelf: 'center' }}>
        <input type="checkbox" checked={trust} onChange={(e) => setTrust(e.target.checked)} />
        Trust this browser for 30 days
      </label>
      <p className="fine">{trust ? "Keeps a locked copy of your key in this browser so it opens without your iPhone. Don't use this on a shared computer." : 'Without this, you unlock each time you open Folio here.'}</p>
      <button className="text-btn" onClick={onSignOut}>Sign out ({me.email ?? 'this account'})</button>
    </Gate>
  );
}

function QRUnlock({ me, onKey }: { me: Me; onKey: (raw: Uint8Array) => void }) {
  const [state, setState] = useState<{ text: string; id: string; pair: CryptoKeyPair } | null>(null);
  const [status, setStatus] = useState<'waiting' | 'expired' | 'error'>('waiting');
  const [problem, setProblem] = useState('');
  const [round, setRound] = useState(0);

  useEffect(() => {
    let live = true;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let id: string | undefined;
    setState(null);
    setStatus('waiting');
    (async () => {
      try {
        const pair = await x25519KeyPair();
        const publicKey = await exportPublicKey(pair.publicKey);
        const created = await api<{ id: string; expiresAt: number }>('POST', 'link', { publicKey: toBase64(publicKey) });
        id = created.id;
        if (!live) return;
        setState({ text: `folio-link:1:${created.id}:${toBase64Url(publicKey)}`, id: created.id, pair });
        const poll = async () => {
          if (!live) return;
          try {
            const reply = await api<{ status: string; senderPublicKey?: string; envelope?: string; nonce?: string }>('GET', `link/${created.id}`);
            if (reply.status === 'approved' && reply.senderPublicKey && reply.envelope && reply.nonce) {
              onKey(await receiveLinkedKey(pair, { senderPublicKey: reply.senderPublicKey, envelope: reply.envelope, nonce: reply.nonce }, created.id, me.userId));
              return;
            }
          } catch (error) {
            if (error instanceof ApiError && (error.status === 410 || error.status === 404)) {
              setStatus('expired');
              return;
            }
          }
          timer = setTimeout(poll, 3000);
        };
        timer = setTimeout(poll, 3000);
      } catch (error) {
        if (live) {
          setStatus('error');
          setProblem(friendly(error));
        }
      }
    })();
    return () => {
      live = false;
      clearTimeout(timer);
      if (id) void api('DELETE', `link/${id}`).catch(() => {});
    };
  }, [round]);

  const path = useMemo(() => {
    if (!state) return '';
    const { data } = encode(state.text, { ecc: 'M', border: 0 });
    let d = '';
    data.forEach((row, y) => row.forEach((on, x) => { if (on) d += `M${x} ${y}h1v1h-1z`; }));
    return `${data.length}|${d}`;
  }, [state]);
  const [size, d] = path.split('|');

  if (status !== 'waiting') {
    return (
      <div style={{ display: 'grid', gap: 12 }}>
        <p className="callout ink2">{status === 'expired' ? 'This code expired after 5 minutes.' : problem}</p>
        <button className="btn primary" onClick={() => setRound(round + 1)}>Show a new code</button>
      </div>
    );
  }
  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <div className="qr" data-link={state?.text} aria-label="Link code for your iPhone" role="img">
        {state ? <svg viewBox={`0 0 ${size} ${size}`} shapeRendering="crispEdges"><path d={d} fill="currentColor" /></svg> : null}
      </div>
      <ol className="steps">
        <li>On your iPhone, open Folio → Profile → <strong>Link a browser or device</strong>.</li>
        <li>Point the camera at this code, then confirm with Face ID.</li>
      </ol>
      <p className="fine" aria-live="polite">Waiting for your iPhone…</p>
    </div>
  );
}

function RecoveryUnlock({ me, onKey }: { me: Me; onKey: (raw: Uint8Array) => void }) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState('');
  async function unlock(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setProblem('');
    try {
      const { envelope } = await api<{ envelope: string }>('GET', 'keys/recovery');
      onKey(await unwrapWithRecoveryKey(envelope, text, me.userId));
    } catch (error) {
      setProblem(error instanceof WrongRecoveryKey ? "That key doesn't match this account. Check each character." : friendly(error));
    } finally {
      setBusy(false);
    }
  }
  return (
    <form onSubmit={unlock} style={{ display: 'grid', gap: 12 }}>
      <label className="sr-only" htmlFor="recovery">Recovery key</label>
      <textarea id="recovery" className="field" rows={2} autoFocus spellCheck={false} autoCapitalize="characters" autoComplete="off"
        placeholder="XXXX-XXXXX-XXXX-XXXX-XXXXX-XXXX" value={text} onChange={(e) => setText(e.target.value)}
        style={{ fontFamily: 'ui-monospace, SF Mono, Menlo, monospace', textAlign: 'center', resize: 'none' }} />
      {problem && <p className="error" role="alert">{problem}</p>}
      <button className="btn primary wide" disabled={busy || text.replace(/[\s-]/g, '').length < 26}>{busy ? 'Unlocking…' : 'Unlock'}</button>
    </form>
  );
}
