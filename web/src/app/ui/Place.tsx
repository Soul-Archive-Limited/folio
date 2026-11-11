import { useEffect, useRef, useState } from 'react';
import { appleMapsURL, MAX_PLACE_NAME, recentPlaces } from '../lib/place.ts';
import type { PlaceData } from '../lib/payloads.ts';
import { useDiary } from './context.tsx';
import { Icon } from './Icons.tsx';

/** "📍 Tate Modern" on cards (Batch N). */
export function PlaceLine({ place }: { place: PlaceData }) {
  return (
    <span className="place-line caption ink3" aria-label={`Place, ${place.name}`}>
      <Icon name="place" small /><span>{place.name}</span>
    </span>
  );
}

/**
 * The place at the end of an entry: name, address and an "Open in Apple Maps" link. No map
 * picture on the web — that would need a third-party map script (DECISIONS 304).
 */
export function PlaceCard({ place }: { place: PlaceData }) {
  return (
    <a className="place-card glass" href={appleMapsURL(place)} target="_blank" rel="noopener noreferrer">
      <Icon name="place" />
      <span className="place-text">
        <span className="callout">{place.name}</span>
        {place.address && <span className="caption ink3">{place.address}</span>}
      </span>
      <span className="callout place-open">Open in Apple Maps<span className="sr-only"> (opens a new tab)</span></span>
    </a>
  );
}

/**
 * The composer's place (Batch N): a chip with the place (Change, Remove), or — while adding —
 * a name field with recent places. Nothing is looked up: on the web a place is the name typed.
 */
export function PlaceField({ place, editing, onEditing, onChange }: {
  place: PlaceData | undefined; editing: boolean; onEditing: (open: boolean) => void; onChange: (place: PlaceData | undefined) => void;
}) {
  const { store } = useDiary();
  const [name, setName] = useState('');
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => { if (editing) { setName(''); input.current?.focus(); } }, [editing]);

  if (editing) {
    const recents = recentPlaces(store.entries()).filter((p) => p.name.toLowerCase().includes(name.trim().toLowerCase()));
    const commit = (chosen: PlaceData | undefined) => { if (chosen?.name.trim()) onChange(chosen); onEditing(false); };
    return (
      <div className="place-edit">
        <form style={{ display: 'flex', gap: 8 }} onSubmit={(e) => { e.preventDefault(); commit({ name: name.trim().slice(0, MAX_PLACE_NAME) }); }}>
          <input ref={input} className="field" aria-label="Place name" placeholder="Place name" maxLength={MAX_PLACE_NAME} value={name}
            onChange={(e) => setName(e.target.value)} onKeyDown={(e) => { if (e.key === 'Escape') { e.stopPropagation(); onEditing(false); } }} style={{ minHeight: 40 }} />
          <button className="btn small primary" disabled={!name.trim()}>Add</button>
          <button type="button" className="btn small" onClick={() => onEditing(false)}>Cancel</button>
        </form>
        {recents.length > 0 && (
          <div className="place-recents" role="group" aria-label="Recent places">
            {recents.map((p) => (
              <button key={`${p.name}|${p.latitude ?? ''}`} type="button" className="chip" onClick={() => commit(p)}>
                <Icon name="place" small />{p.name}
              </button>
            ))}
          </div>
        )}
        <p className="caption ink3" style={{ margin: 0 }}>On the web a place is its name. Add it from your iPhone to put it on the map.</p>
      </div>
    );
  }
  if (!place) return null;
  return (
    <div className="place-chip glass">
      <Icon name="place" small />
      <button type="button" className="place-name" onClick={() => onEditing(true)} aria-label={`Place, ${place.name}. Change`}>{place.name}</button>
      <button type="button" className="x" aria-label="Remove place" onClick={() => onChange(undefined)}><Icon name="close" small /></button>
    </div>
  );
}
