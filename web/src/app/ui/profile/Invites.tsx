import { useEffect, useState } from 'react';
import { api, friendly } from '../../lib/api.ts';
import { useDiary } from '../context.tsx';
import { Back } from './ProfileView.tsx';

interface Invite { id: string; hint: string; createdAt: number; expiresAt: number; status: 'open' | 'used' | 'revoked' | 'expired' }
const fmt = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short' });

/** Invite a friend (Batch J, owner only): a one-time code for 7 days; revoke unused ones. */
export default function Invites() {
  const { toast } = useDiary();
  const [invites, setInvites] = useState<Invite[] | null>(null);
  const [fresh, setFresh] = useState<{ code: string; expiresAt: number } | null>(null);
  const [problem, setProblem] = useState('');

  async function load() {
    try {
      setInvites((await api<{ invites: Invite[] }>('GET', 'invites')).invites);
    } catch (error) {
      setProblem(friendly(error));
    }
  }
  useEffect(() => { void load(); }, []);

  async function make() {
    try {
      setFresh(await api<{ code: string; expiresAt: number }>('POST', 'invites', {}));
      setProblem('');
      await load();
    } catch (error) {
      setProblem(friendly(error));
    }
  }

  async function revoke(id: string) {
    try {
      await api('DELETE', `invites/${id}`);
      await load();
    } catch (error) {
      setProblem(friendly(error));
    }
  }

  const message = fresh ? `Join me on Folio, a private diary. Your invite code: ${fresh.code} (works once, for 7 days). Get Folio: https://folio.devilsense.com/download` : '';
  async function share() {
    if (navigator.share) await navigator.share({ text: message }).catch(() => {});
    else { await navigator.clipboard.writeText(message); toast('Invite copied'); }
  }

  return (
    <>
      <Back title="Invite a friend" />
      <p className="ink2">Folio is invite-only for now. Each code makes one new account and lasts 7 days. People who already have an account don't need one.</p>
      {fresh && (
        <div className="group glass" style={{ padding: 20, textAlign: 'center', display: 'grid', gap: 10 }}>
          <code style={{ fontSize: 30, fontWeight: 700, letterSpacing: 2 }}>{fresh.code}</code>
          <span className="caption ink3">Works once, until {fmt.format(fresh.expiresAt)}</span>
          <button className="btn primary" onClick={share}>Share invite</button>
        </div>
      )}
      <button className="btn" style={{ margin: '14px 0' }} onClick={make}>{fresh ? 'Make another' : 'Make an invite'}</button>
      {problem && <p className="error" role="alert">{problem}</p>}
      {invites && invites.length > 0 && (
        <div className="group glass">
          {invites.map((i) => (
            <div key={i.id} className="row">
              <code className="grow">····-··{i.hint}</code>
              <span className="value">{i.status === 'open' ? `Until ${fmt.format(i.expiresAt)}` : i.status[0]!.toUpperCase() + i.status.slice(1)}</span>
              {i.status === 'open' && <button className="btn small" onClick={() => revoke(i.id)}>Revoke</button>}
            </div>
          ))}
        </div>
      )}
    </>
  );
}
