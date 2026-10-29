import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { newId, sameId } from '../lib/bytes.ts';
import { formatLongYear, formatTime } from '../lib/days.ts';
import { photoBytes, type PreparedPhoto, type Rendition } from '../lib/photos.ts';
import { CategoryChip, PhotoImg, Sheet, useCloseSheet } from './common.tsx';
import { useDiary } from './context.tsx';
import { EntryCard } from './EntryCard.tsx';
import { Icon } from './Icons.tsx';
import { Prose } from './Prose.tsx';

/** Entry detail (SPEC §6.5): photos, date, category, title, the text; Edit · ••• menu. */
export default function EntryDetail({ id, onClose }: { id: string; onClose: () => void }) {
  return (
    <Sheet label="Entry" onClose={onClose} wide scrim tall>
      <Detail id={id} />
    </Sheet>
  );
}

function Detail({ id }: { id: string }) {
  const diary = useDiary();
  const { store, openComposer, toast, engine, key, me } = diary;
  const close = useCloseSheet();
  const entry = store.get('entry', id);
  const [menu, setMenu] = useState(false);
  const [viewing, setViewing] = useState<number | null>(null);
  useEffect(() => { if (!entry || entry.data.trashedAt) close(); }, [entry?.data.trashedAt, !!entry]);
  if (!entry) return null;
  const photos = store.photosOf(entry.id);
  const others = store.entries().filter((e) => !sameId(e.id, entry.id) && e.data.dayKey.slice(5) === entry.data.dayKey.slice(5) && e.data.dayKey !== entry.data.dayKey)
    .sort((a, b) => b.data.dayKey.localeCompare(a.data.dayKey));

  function remove() {
    store.trash('entry', entry!.id);
    toast('Moved to Recently Deleted', { label: 'Undo', run: () => store.restore('entry', entry!.id) });
    close();
  }

  async function duplicate() {
    setMenu(false);
    const copyId = store.put('entry', { ...entry!.data, createdAt: Date.now(), trashedAt: undefined });
    for (const [sortIndex, photo] of photos.entries()) {
      // Not fetch(blob:): the CSP's connect-src is 'self' only.
      const bytes = (r: Rendition) => photoBytes(key, me.userId, photo.id, r);
      const [thumb, display, full] = await Promise.all([bytes('thumb'), bytes('display'), bytes('full')]);
      if (!thumb || !display || !full) continue;
      const copy: PreparedPhoto = { thumb, display, full, width: photo.data.pixelWidth, height: photo.data.pixelHeight, previewURL: URL.createObjectURL(new Blob([display as BlobPart])) };
      const photoId = newId();
      store.put('entryPhoto', { ...photo.data, entryID: copyId, sortIndex, createdAt: Date.now() }, photoId, { waitingForBlob: true });
      engine.addPhoto(photoId, copy);
    }
    toast('Duplicated', { label: 'Show', run: () => diary.openEntry(copyId) });
  }

  return (
    <>
      <div className="sheet-bar">
        <button className="icon-btn" aria-label="Close" onClick={close}><Icon name="close" /></button>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn small" onClick={() => openComposer({ entryId: entry.id })}><Icon name="edit" small />Edit</button>
          <button className="icon-btn" aria-label="More" aria-expanded={menu} onClick={() => setMenu(!menu)}><Icon name="more" /></button>
        </div>
        {menu && (
          <div className="menu glass" role="menu">
            <label className="row" style={{ border: 0, minHeight: 44, padding: '0 12px', position: 'relative', cursor: 'pointer' }}>
              <Icon name="calendar" small />Change date
              <input type="date" min="1900-01-01" aria-label="Change date" value={entry.data.dayKey} style={{ position: 'absolute', inset: 0, opacity: 0 }}
                onChange={(e) => { if (e.target.value) { store.put('entry', { dayKey: e.target.value }, entry.id); setMenu(false); toast(`Moved to ${formatLongYear(e.target.value)}`); } }} />
            </label>
            <button role="menuitem" onClick={() => void duplicate()}><Icon name="copy" small />Duplicate</button>
            <button role="menuitem" onClick={() => { setMenu(false); void navigator.clipboard.writeText([entry.data.title, entry.data.bodyMarkdown].filter(Boolean).join('\n\n')); toast('Text copied'); }}><Icon name="share" small />Copy text</button>
            <button role="menuitem" className="danger" onClick={remove}><Icon name="trash" small />Delete</button>
          </div>
        )}
      </div>
      <div className="sheet-body" onClick={() => menu && setMenu(false)}>
        {photos.length > 0 && (
          <div className="carousel" aria-label="Photos">
            {photos.map((p, i) => (
              <button key={p.id} aria-label={`Photo ${i + 1} of ${photos.length}. Open full size`} onClick={() => setViewing(i)}><PhotoImg id={p.id} rendition="display" /></button>
            ))}
          </div>
        )}
        <p className="caption ink3">{formatLongYear(entry.data.dayKey)}{entry.data.minutesFromMidnight !== undefined && ` · ${formatTime(entry.data.minutesFromMidnight)}`}</p>
        <div style={{ margin: '8px 0' }}><CategoryChip id={entry.data.categoryID} /></div>
        {entry.data.title && <h1 className="title2" style={{ fontSize: 28, margin: '6px 0 12px' }}>{entry.data.title}</h1>}
        <Prose markdown={entry.data.bodyMarkdown} />
        {others.length > 0 && (
          <section className="same-day">
            <h2 className="caption ink3">Same day in other years</h2>
            {others.slice(0, 5).map((e) => <EntryCard key={e.id} entry={e} showDate />)}
          </section>
        )}
      </div>
      {viewing !== null && photos[viewing] && <Lightbox ids={photos.map((p) => p.id)} start={viewing} onClose={() => setViewing(null)} />}
    </>
  );
}

/** Full-screen photo with all three renditions to choose from. */
function Lightbox({ ids, start, onClose }: { ids: string[]; start: number; onClose: () => void }) {
  const [index, setIndex] = useState(start);
  const [rendition, setRendition] = useState<Rendition>('full');
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onClose(); }
      if (e.key === 'ArrowRight') setIndex((i) => Math.min(ids.length - 1, i + 1));
      if (e.key === 'ArrowLeft') setIndex((i) => Math.max(0, i - 1));
    };
    window.addEventListener('keydown', key, true);
    return () => window.removeEventListener('keydown', key, true);
  }, []);
  // Portalled to <body>: the sheet's backdrop-filter would otherwise contain a fixed overlay.
  return createPortal(
    <div className="lightbox" role="dialog" aria-modal="true" aria-label="Photo" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="bar">
        <button className="icon-btn" aria-label="Close" onClick={onClose} style={{ color: '#fff', background: 'rgb(255 255 255 / 0.15)' }}><Icon name="close" /></button>
        <div className="segmented" role="group" aria-label="Size">
          {(['thumb', 'display', 'full'] as const).map((r) => (
            <button key={r} aria-pressed={rendition === r} onClick={() => setRendition(r)}>{{ thumb: 'Thumbnail', display: 'Display', full: 'Full' }[r]}</button>
          ))}
        </div>
        <span className="callout" style={{ alignSelf: 'center' }}>{index + 1} / {ids.length}</span>
      </div>
      <PhotoImg key={`${ids[index]}-${rendition}`} id={ids[index]!} rendition={rendition} fallback={rendition !== 'thumb'} />
    </div>,
    document.body,
  );
}
