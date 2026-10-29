import { useEffect, useState } from 'react';
import { api, type Device, friendly } from '../../lib/api.ts';
import { fromUtf8, utf8 } from '../../lib/bytes.ts';
import { openRecord, sealRecord } from '../../lib/crypto.ts';
import { Modal } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';
import { Back } from './ProfileView.tsx';

const fmtDate = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
const rtf = new Intl.RelativeTimeFormat('en-GB', { numeric: 'auto' });
function lastSeen(at: number) {
  const minutes = (Date.now() - at) / 60_000;
  if (minutes < 60) return 'Active in the last hour';
  if (minutes < 60 * 24) return `Last seen ${rtf.format(-Math.round(minutes / 60), 'hour')}`;
  return `Last seen ${rtf.format(-Math.round(minutes / 1440), 'day')}`;
}

/** Devices (SPEC §6.9, DECISIONS 189): model + OS, dates, this one, encrypted names. */
export default function Devices() {
  const { key, me, toast } = useDiary();
  const [devices, setDevices] = useState<(Device & { nickname?: string })[] | null>(null);
  const [problem, setProblem] = useState('');
  const [renaming, setRenaming] = useState<Device | null>(null);
  const [name, setName] = useState('');
  const [others, setOthers] = useState(false);

  async function load() {
    try {
      const { devices: list } = await api<{ devices: Device[] }>('GET', 'account/devices');
      setDevices(await Promise.all(list.map(async (d) => {
        if (!d.label) return d;
        try { return { ...d, nickname: fromUtf8(await openRecord(key, d.label.ciphertext, d.label.nonce, d.id, 'deviceLabel', me.userId)) }; } catch { return d; }
      })));
      setProblem('');
    } catch (error) {
      setProblem(friendly(error));
    }
  }
  useEffect(() => { void load(); }, []);

  async function rename() {
    const device = renaming!;
    setRenaming(null);
    const clean = name.trim().slice(0, 40);
    try {
      const label = clean ? await sealRecord(key, utf8.encode(clean), device.id, 'deviceLabel', me.userId) : null;
      await api('PUT', `account/devices/${device.id}/label`, { label });
      await load();
    } catch (error) { toast(friendly(error)); }
  }

  async function signOut(id: string) {
    try { await api('DELETE', `account/devices/${id}`); await load(); } catch (error) { toast(friendly(error)); }
  }

  return (
    <>
      <Back title="Devices" />
      {problem && <p className="callout ink2">{problem}</p>}
      {devices && (
        <>
          <div className="group glass">
            {devices.map((d) => (
              <div key={d.id} className="row device-row">
                <Icon name={d.platform === 'web' ? 'globe' : 'iphone'} />
                <span className="grow">
                  <span style={{ display: 'block' }}>{d.nickname ?? d.name}</span>
                  {d.nickname && <span className="callout ink2" style={{ display: 'block' }}>{d.name}</span>}
                  <span className="callout ink3" style={{ display: 'block' }}>Added {fmtDate.format(d.createdAt)}{d.current ? '' : ` · ${lastSeen(d.lastSeenAt)}`}</span>
                </span>
                <span className="actions-line">
                  {d.current && <span className="badge">This device</span>}
                  <button className="btn small" onClick={() => { setName(d.nickname ?? ''); setRenaming(d); }}>Rename</button>
                  {!d.current && <button className="btn small danger" onClick={() => void signOut(d.id)}>Sign out</button>}
                </span>
              </div>
            ))}
          </div>
          <p className="group-foot">Names you give devices are encrypted like your diary. A signed-out device keeps its copy until it's signed out there too.</p>
          {devices.length > 1 && <button className="btn danger" onClick={() => setOthers(true)}>Sign out other devices</button>}
        </>
      )}
      {renaming && (
        <Modal title="Rename device" message="Leave it empty to show the model again." onClose={() => setRenaming(null)}>
          <form onSubmit={(e) => { e.preventDefault(); void rename(); }} style={{ display: 'grid', gap: 12, width: '100%' }}>
            <input className="field" autoFocus maxLength={40} placeholder={renaming.name} aria-label="Device name" value={name} onChange={(e) => setName(e.target.value)} />
            <div className="actions"><button type="button" className="btn" onClick={() => setRenaming(null)}>Cancel</button><button className="btn primary">Save</button></div>
          </form>
        </Modal>
      )}
      {others && (
        <Modal title="Sign out every other device and browser?" onClose={() => setOthers(false)}>
          <button className="btn" onClick={() => setOthers(false)}>Cancel</button>
          <button className="btn solid-danger" onClick={() => { setOthers(false); void api('POST', 'account/devices/sign-out-others', {}).then(load).catch((e) => toast(friendly(e))); }}>Sign out others</button>
        </Modal>
      )}
    </>
  );
}
