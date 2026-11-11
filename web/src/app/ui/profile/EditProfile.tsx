import { useRef, useState } from 'react';
import type { SettingsData } from '../../lib/payloads.ts';
import { Avatar, AvatarGrid } from '../Avatar.tsx';
import { Sheet, useCloseSheet } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { useSettings } from './ProfileView.tsx';

/**
 * Edit profile (Batch N Part 3), as on the iPhone: the large picture with Choose photo, Folio
 * avatars and Remove photo, the name under it, and Save / Cancel. Save writes the encrypted
 * settings record at once, so every device updates.
 */
export function EditProfile({ onClose }: { onClose: () => void }) {
  return (
    <Sheet label="Edit profile" onClose={onClose} scrim>
      <EditProfileBody />
    </Sheet>
  );
}

const MAX_NAME = 40;

/** A square, centred 256 px JPEG of an image file, as base64 (what the iPhone's crop saves). */
export async function squareAvatar(file: Blob): Promise<string> {
  const bitmap = await createImageBitmap(file);
  const side = Math.min(bitmap.width, bitmap.height);
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 256;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('canvas');
  context.drawImage(bitmap, (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side, 0, 0, 256, 256);
  bitmap.close();
  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.85));
  if (!blob) throw new Error('encode');
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

function EditProfileBody() {
  const { me, toast } = useDiary();
  const close = useCloseSheet();
  const [settings, update] = useSettings();
  const [name, setName] = useState(settings.displayName);
  const [avatar, setAvatar] = useState<string | undefined>(settings.avatar);
  const [photo, setPhoto] = useState<string | undefined>(settings.avatar === 'photo' ? settings.avatarPhoto : undefined);
  const [picking, setPicking] = useState(false);
  const file = useRef<HTMLInputElement>(null);
  const preview: SettingsData = { ...settings, displayName: name, avatar, avatarPhoto: photo };

  async function choose(input: FileList | null) {
    const picked = input?.[0];
    if (!picked) return;
    try {
      setPhoto(await squareAvatar(picked));
      setAvatar('photo');
      setPicking(false);
    } catch {
      toast("This browser can't open that photo. Try a JPEG or PNG.");
    }
  }

  function save() {
    const clean = name.trim().slice(0, MAX_NAME);
    const nextPhoto = avatar === 'photo' ? photo : undefined;
    if (clean !== settings.displayName || avatar !== settings.avatar || nextPhoto !== (settings.avatar === 'photo' ? settings.avatarPhoto : undefined)) {
      update({ displayName: clean, avatar, avatarPhoto: nextPhoto });
    }
    close();
  }

  return (
    <>
      <div className="sheet-bar">
        <button className="btn small" onClick={close}>Cancel</button>
        <h2 className="headline" style={{ margin: 0 }}>Edit profile</h2>
        <button className="btn small primary" onClick={save}>Save</button>
      </div>
      <div className="sheet-body edit-profile">
        <div className="edit-avatar" key={`${avatar ?? ''}|${photo?.length ?? 0}`}><Avatar settings={preview} fallback={name || me.email || 'F'} big /></div>
        <div className="edit-actions">
          <button type="button" className="btn small" onClick={() => file.current?.click()}>Choose photo</button>
          <button type="button" className="btn small" aria-expanded={picking} onClick={() => setPicking(!picking)}>Folio avatars</button>
          {avatar && <button type="button" className="btn small danger" onClick={() => { setAvatar(undefined); setPhoto(undefined); }}>Remove photo</button>}
          <input ref={file} type="file" accept="image/*" className="sr-only" tabIndex={-1} aria-hidden="true" onChange={(e) => { void choose(e.target.files); e.target.value = ''; }} />
        </div>
        {picking && <AvatarGrid current={avatar} onPick={(key) => { setAvatar(key); setPhoto(undefined); setPicking(false); }} />}
        <label className="edit-name">
          <span className="caption ink2">Name</span>
          <input className="field" placeholder="Your name" maxLength={MAX_NAME} value={name} autoComplete="given-name"
            onChange={(e) => setName(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); save(); } }} />
        </label>
        <p className="callout ink2" style={{ margin: 0 }}>Used to greet you. It syncs end-to-end encrypted.</p>
      </div>
    </>
  );
}
