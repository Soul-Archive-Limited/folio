import type { CSSProperties } from 'react';
import { formatShort, formatTime } from '../lib/days.ts';
import { plainText } from '../lib/markdown.ts';
import type { EntryData } from '../lib/payloads.ts';
import type { Rec } from '../lib/store.ts';
import { CategoryChip, PhotoImg } from './common.tsx';
import { useDiary } from './context.tsx';

/** An entry in the day panel or a list: 64 pt photo, title, two-line preview, category, time. */
export function EntryCard({ entry, style, showDate }: { entry: Rec<EntryData>; style?: CSSProperties; showDate?: boolean }) {
  const { store, openEntry } = useDiary();
  const photo = store.photosOf(entry.id)[0];
  const preview = plainText(entry.data.bodyMarkdown).replace(/\n+/g, ' ').trim();
  const title = entry.data.title.trim() || preview.split(/[.!?]/)[0]?.slice(0, 60) || 'Untitled';
  const time = entry.data.minutesFromMidnight !== undefined ? formatTime(entry.data.minutesFromMidnight) : '';
  return (
    <button className="card" style={style} onClick={() => openEntry(entry.id)}>
      {photo && <span className="thumb"><PhotoImg id={photo.id} rendition="thumb" /></span>}
      <span style={{ minWidth: 0, flex: 1 }}>
        <span className="t" style={{ display: 'block' }}>{title}</span>
        {preview && entry.data.title.trim() && <span className="p">{preview}</span>}
        <span className="meta">
          <CategoryChip id={entry.data.categoryID} />
          {(showDate || time) && <span className="caption ink3">{[showDate && formatShort(entry.data.dayKey), time].filter(Boolean).join(' · ')}</span>}
        </span>
      </span>
    </button>
  );
}
