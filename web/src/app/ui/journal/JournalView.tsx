import { useMemo, useState } from 'react';
import { sameId } from '../../lib/bytes.ts';
import { formatMonthYear, formatShort } from '../../lib/days.ts';
import { byTimeInDay } from '../../lib/markers.ts';
import { plainText } from '../../lib/markdown.ts';
import { CategoryChips, Empty, PhotoImg } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { EntryCard } from '../EntryCard.tsx';
import { Icon } from '../Icons.tsx';

/** Journal (SPEC §6.6): Timeline with sticky months and cover cards, or every photo. */
export default function JournalView() {
  const { store, openComposer, openEntry, navigate } = useDiary();
  const [mode, setMode] = useState<'timeline' | 'photos'>('timeline');
  const [category, setCategory] = useState<string | null>(null);
  const entries = useMemo(() => store.entries()
    .filter((e) => !category || sameId(e.data.categoryID, category))
    .sort((a, b) => b.data.dayKey.localeCompare(a.data.dayKey) || byTimeInDay(b, a)), [store.revision, category]);
  const months = useMemo(() => {
    const groups: { key: string; items: typeof entries }[] = [];
    for (const e of entries) {
      const key = e.data.dayKey.slice(0, 7);
      if (groups[groups.length - 1]?.key !== key) groups.push({ key, items: [] });
      groups[groups.length - 1]!.items.push(e);
    }
    return groups;
  }, [entries]);
  const photos = useMemo(() => entries.flatMap((e) => store.photosOf(e.id).map((p) => ({ photo: p, entry: e }))), [entries]);
  const trashCount = store.trashed().entries.length;

  return (
    <div className="scroll">
      <div className="page">
        <div className="page-title">
          <h1 className="title1">Journal</h1>
          <div className="segmented glass" role="group" aria-label="View">
            <button aria-pressed={mode === 'timeline'} onClick={() => setMode('timeline')}>Timeline</button>
            <button aria-pressed={mode === 'photos'} onClick={() => setMode('photos')}>Photos</button>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginBottom: 8, flexWrap: 'wrap' }}>
          <CategoryChips selected={category} onSelect={setCategory} />
          <button className="btn small" onClick={() => openComposer({ dayKey: undefined })} style={{ marginLeft: 'auto' }}><Icon name="calendar" small />Write for a past day</button>
        </div>
        {entries.length === 0 ? (
          <Empty icon="journal" text={category ? 'No pages in this category yet.' : 'Your journal is empty. Tap + to write your first page.'} />
        ) : mode === 'timeline' ? (
          months.map((m) => (
            <section key={m.key} aria-label={formatMonthYear(`${m.key}-01`)}>
              <h2 className="month-head title2">{formatMonthYear(`${m.key}-01`)}</h2>
              {m.items.map((e) => {
                const cover = store.photosOf(e.id)[0];
                if (!cover) return <EntryCard key={e.id} entry={e} showDate />;
                return (
                  <button key={e.id} className="cover" onClick={() => openEntry(e.id)}>
                    <PhotoImg id={cover.id} rendition="display" />
                    <span className="over">
                      <span className="caption" style={{ opacity: 0.85 }}>{formatShort(e.data.dayKey)}</span>
                      <span className="title2" style={{ display: 'block' }}>{e.data.title || plainText(e.data.bodyMarkdown).split('\n')[0] || 'Untitled'}</span>
                    </span>
                  </button>
                );
              })}
            </section>
          ))
        ) : photos.length === 0 ? (
          <Empty icon="photo" text="No photos yet." />
        ) : (
          <div className="masonry">
            {photos.map(({ photo, entry }) => (
              <button key={photo.id} onClick={() => openEntry(entry.id)} aria-label={`Photo from ${formatShort(entry.data.dayKey)}`}
                style={{ aspectRatio: `${photo.data.pixelWidth || 4} / ${photo.data.pixelHeight || 3}` }}>
                <PhotoImg id={photo.id} rendition="display" />
              </button>
            ))}
          </div>
        )}
        {trashCount > 0 && <p style={{ textAlign: 'center', marginTop: 24 }}><button className="link" onClick={() => navigate('/app/profile/deleted')}>Recently Deleted · {trashCount}</button></p>}
      </div>
    </div>
  );
}
