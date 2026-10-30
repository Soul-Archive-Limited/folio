import type { SettingsData } from '../lib/payloads.ts';

/** Folio avatars "folio:01" … "folio:24" (Batch I); the SVGs come from scripts/avatars/generate.py. */
export const AVATAR_COUNT = 24;
const AVATAR_KEY = /^folio:(0[1-9]|1\d|2[0-4])$/;
/** Base64 only: the photo goes into a data: URL with a fixed JPEG type, never anything else. */
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

export const avatarKey = (n: number) => `folio:${String(n).padStart(2, '0')}`;
export const avatarSrc = (n: number) => `/avatars/avatar-${String(n).padStart(2, '0')}.svg`;

/** The picture the person chose on any device: a Folio avatar, their photo, or the initial. */
export function Avatar({ settings, fallback, big }: { settings?: SettingsData; fallback: string; big?: boolean }) {
  const cls = big ? 'avatar big' : 'avatar';
  const key = settings?.avatar;
  const match = key ? AVATAR_KEY.exec(key) : null;
  if (match) return <img className={`${cls} pic`} src={avatarSrc(Number(match[1]))} alt="" aria-hidden="true" />;
  const photo = settings?.avatarPhoto;
  if (key === 'photo' && photo && photo.length < 400_000 && BASE64.test(photo)) {
    return <img className={`${cls} pic`} src={`data:image/jpeg;base64,${photo}`} alt="" aria-hidden="true" />;
  }
  return <span className={cls} aria-hidden="true">{(fallback || 'F').slice(0, 1).toUpperCase()}</span>;
}

/** The 24 Folio avatars to choose from (the photo crop stays on the iPhone). */
export function AvatarGrid({ current, onPick }: { current?: string; onPick: (key: string) => void }) {
  return (
    <div className="avatar-grid" role="listbox" aria-label="Folio avatars">
      {Array.from({ length: AVATAR_COUNT }, (_, i) => i + 1).map((n) => (
        <button key={n} type="button" role="option" aria-selected={current === avatarKey(n)} className="avatar-option"
          onClick={() => onPick(avatarKey(n))} aria-label={`Avatar ${n}`}>
          <img src={avatarSrc(n)} alt="" width={56} height={56} />
        </button>
      ))}
    </div>
  );
}
