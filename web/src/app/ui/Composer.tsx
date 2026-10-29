import { useEffect, useRef, useState } from 'react';
import { newId } from '../lib/bytes.ts';
import { formatShort, formatTime, pad, todayKey } from '../lib/days.ts';
import { CATEGORY_COLORS } from '../lib/payloads.ts';
import { deletePhotoBlobs, MAX_PHOTOS, preparePhoto, type PreparedPhoto, UnsupportedPhoto } from '../lib/photos.ts';
import { CategoryChips, IPhoneOnly, Modal, PhotoImg, Sheet, useCloseSheet } from './common.tsx';
import { type ComposerRequest, useDiary } from './context.tsx';
import { EditorBody, editorMarkdown, FormatPopover, useFolioEditor } from './Editor.tsx';
import { Icon } from './Icons.tsx';

type PhotoItem = { id: string; existing: true } | { id: string; existing: false; prepared: PreparedPhoto };

/**
 * The composer (SPEC §6.4, §11.3): a right-side glass sheet so the calendar stays in view —
 * clicking another day moves the entry there — or a bottom drawer on phones.
 */
export default function Composer(props: { request: ComposerRequest; day: string; onDayChange: (day: string) => void; onClose: () => void }) {
  const [asking, setAsking] = useState(false);
  const dirty = useRef(false);
  return (
    <Sheet label={props.request.entryId ? 'Edit entry' : 'New entry'} onClose={props.onClose}
      canClose={() => (dirty.current ? (setAsking(true), false) : true)}>
      <ComposerBody {...props} dirty={dirty} />
      {asking && (
        <Modal title="Discard this entry?" message="What you've written here will be lost." onClose={() => setAsking(false)}>
          <button className="btn" onClick={() => setAsking(false)}>Keep editing</button>
          <button className="btn solid-danger" onClick={props.onClose}>Discard</button>
        </Modal>
      )}
    </Sheet>
  );
}

function ComposerBody({ request, day, onDayChange, dirty }: { request: ComposerRequest; day: string; onDayChange: (d: string) => void; onClose: () => void; dirty: React.MutableRefObject<boolean> }) {
  const { store, engine, toast } = useDiary();
  const close = useCloseSheet();
  const existing = request.entryId ? store.get('entry', request.entryId) : undefined;
  const [dayKey, setDayKey] = useState(existing?.data.dayKey ?? request.dayKey ?? todayKey());
  const [minutes, setMinutes] = useState<number | undefined>(existing?.data.minutesFromMidnight);
  const [title, setTitle] = useState(existing?.data.title ?? '');
  const [categoryId, setCategoryId] = useState<string | null>(existing?.data.categoryID ?? request.categoryId ?? store.settings?.defaultCategoryID ?? null);
  const [photos, setPhotos] = useState<PhotoItem[]>(existing ? store.photosOf(existing.id).map((p) => ({ id: p.id, existing: true })) : []);
  const [bodyEmpty, setBodyEmpty] = useState(!existing?.data.bodyMarkdown);
  const [format, setFormat] = useState(false);
  const [notice, setNotice] = useState(false);
  const [newCategory, setNewCategory] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [dragging, setDragging] = useState<number | null>(null);
  const opened = useRef(day);
  const placeholder = dayKey < todayKey() ? 'What do you remember about this day?' : 'What happened today?';
  const editor = useFolioEditor(existing?.data.bodyMarkdown ?? '', placeholder, () => {
    dirty.current = true;
    setBodyEmpty(editor?.isEmpty ?? true);
  });

  useEffect(() => { onDayChange(dayKey); }, []);
  // Clicking a day in the calendar while writing moves the entry there (SPEC §6.4).
  useEffect(() => {
    if (day !== opened.current) {
      opened.current = day;
      setDayKey(day);
      dirty.current = true;
    }
  }, [day]);

  const touch = <T,>(set: (v: T) => void) => (v: T) => { dirty.current = true; set(v); };
  const canSave = !!title.trim() || !bodyEmpty || photos.length > 0;

  async function addFiles(files: FileList | null) {
    if (!files) return;
    const room = MAX_PHOTOS - photos.length;
    const picked = [...files].slice(0, room);
    if (files.length > room) toast(`Up to ${MAX_PHOTOS} photos per entry.`);
    for (const file of picked) {
      try {
        const prepared = await preparePhoto(file);
        dirty.current = true;
        setPhotos((list) => [...list, { id: newId(), existing: false, prepared }]);
      } catch (error) {
        toast(error instanceof UnsupportedPhoto ? "This browser can't open that photo. Try a JPEG or PNG." : "Couldn't add that photo.");
      }
    }
  }

  function save() {
    if (!editor || !canSave) return;
    setBusy(true);
    const entryId = store.put('entry', {
      title: title.trim().slice(0, 120), bodyMarkdown: editorMarkdown(editor), dayKey, minutesFromMidnight: minutes,
      categoryID: categoryId ?? undefined, ...(existing ? {} : { createdAt: Date.now() }),
    }, existing?.id);
    const kept = new Set(photos.filter((p) => p.existing).map((p) => p.id.toLowerCase()));
    if (existing) {
      for (const old of store.photosOf(existing.id)) {
        if (!kept.has(old.id.toLowerCase())) {
          store.destroy('entryPhoto', old.id);
          void deletePhotoBlobs(old.id);
        }
      }
    }
    photos.forEach((p, sortIndex) => {
      if (p.existing) {
        if (store.get('entryPhoto', p.id)?.data.sortIndex !== sortIndex) store.put('entryPhoto', { sortIndex }, p.id);
      } else {
        store.put('entryPhoto', { entryID: entryId, sortIndex, pixelWidth: p.prepared.width, pixelHeight: p.prepared.height, createdAt: Date.now() }, p.id, { waitingForBlob: true });
        engine.addPhoto(p.id, p.prepared);
      }
    });
    dirty.current = false;
    toast(existing ? 'Saved' : `Saved to ${formatShort(dayKey)}`);
    close();
  }

  function createCategory(name: string) {
    const clean = name.trim().slice(0, 24);
    if (!clean) return setNewCategory(null);
    const same = store.categories().find((c) => c.data.name.toLowerCase() === clean.toLowerCase());
    const used = new Set(store.categories().map((c) => c.data.colorKey));
    const id = same?.id ?? store.put('category', {
      name: clean, colorKey: CATEGORY_COLORS.find((c) => !used.has(c)) ?? 'graphite', sortIndex: store.categories().length, createdAt: Date.now(),
    });
    touch(setCategoryId)(id);
    setNewCategory(null);
  }

  return (
    <>
      <div className="sheet-bar">
        <button className="btn small" onClick={close}>Cancel</button>
        <span className="date-pill">
          <Icon name="calendar" small />{formatShort(dayKey)}{minutes !== undefined && ` · ${formatTime(minutes)}`}
          <input type="date" aria-label="Day" min="1900-01-01" value={dayKey} onChange={(e) => e.target.value && (touch(setDayKey)(e.target.value), onDayChange(e.target.value))} />
        </span>
        <button className="btn small primary" disabled={!canSave || busy} onClick={save}>Save</button>
      </div>
      <div className="sheet-body">
        <input className="title-input" placeholder="Title" aria-label="Title" maxLength={120} value={title} onChange={(e) => touch(setTitle)(e.target.value)} />
        <EditorBody editor={editor} placeholder={placeholder} />
        {photos.length > 0 && (
          <div className="photo-strip" aria-label="Photos">
            {photos.map((p, i) => (
              <div key={p.id} className={`ph${dragging === i ? ' dragging' : ''}`} draggable
                onDragStart={() => setDragging(i)} onDragEnd={() => setDragging(null)} onDragOver={(e) => e.preventDefault()}
                onDrop={() => {
                  if (dragging === null || dragging === i) return;
                  const list = [...photos];
                  const [moved] = list.splice(dragging, 1);
                  list.splice(i, 0, moved!);
                  touch(setPhotos)(list);
                }}>
                {p.existing ? <PhotoImg id={p.id} rendition="thumb" /> : <img src={p.prepared.previewURL} alt="" />}
                <button className="x" aria-label="Remove photo" onClick={() => touch(setPhotos)(photos.filter((x) => x.id !== p.id))}><Icon name="close" /></button>
              </div>
            ))}
          </div>
        )}
        <div style={{ display: 'grid', gap: 10, marginTop: 8 }}>
          <label className="check callout">
            <input type="checkbox" checked={minutes !== undefined} onChange={(e) => touch(setMinutes)(e.target.checked ? new Date().getHours() * 60 + new Date().getMinutes() : undefined)} />
            Add a time
            {minutes !== undefined && (
              <input type="time" className="field" style={{ width: 130, minHeight: 40, padding: '6px 10px' }} aria-label="Time"
                value={`${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`}
                onChange={(e) => { const [h, m] = e.target.value.split(':').map(Number); if (h !== undefined && m !== undefined) touch(setMinutes)(h * 60 + m); }} />
            )}
          </label>
          {newCategory === null ? (
            <CategoryChips selected={categoryId} onSelect={touch(setCategoryId)} allLabel="None" onCreate={() => setNewCategory('')} />
          ) : (
            <form onSubmit={(e) => { e.preventDefault(); createCategory(newCategory); }} style={{ display: 'flex', gap: 8 }}>
              <input className="field" autoFocus maxLength={24} placeholder="New category" value={newCategory} onChange={(e) => setNewCategory(e.target.value)} style={{ minHeight: 40 }} />
              <button className="btn small primary">Add</button>
            </form>
          )}
        </div>
      </div>
      <div className="toolbar" role="toolbar" aria-label="Entry tools" style={{ position: 'relative' }}>
        {format && editor && <FormatPopover editor={editor} onClose={() => setFormat(false)} />}
        {notice && <IPhoneOnly onDone={() => setNotice(false)} />}
        <button className="icon-btn" aria-label="Text styles" aria-pressed={format} onClick={() => setFormat(!format)}><Icon name="textformat" /></button>
        <label className="icon-btn" aria-label="Add photos" title="Add photos" style={{ cursor: 'pointer' }}>
          <Icon name="photo" />
          <input type="file" accept="image/*" multiple className="sr-only" onChange={(e) => { void addFiles(e.target.files); e.target.value = ''; }} disabled={photos.length >= MAX_PHOTOS} />
        </label>
        <span className="sep" />
        <button className="icon-btn" aria-label="Dictate — available in the iPhone app" onClick={() => setNotice(true)}><Icon name="mic" /></button>
        <button className="icon-btn" aria-label="Writing tools — available in the iPhone app" onClick={() => setNotice(true)}><Icon name="sparkle" /></button>
      </div>
    </>
  );
}
