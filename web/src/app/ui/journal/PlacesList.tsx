import { formatShort } from '../../lib/days.ts';
import { appleMapsURL, placeGroups } from '../../lib/place.ts';
import type { EntryData } from '../../lib/payloads.ts';
import type { Rec } from '../../lib/store.ts';
import { Empty } from '../common.tsx';
import { useDiary } from '../context.tsx';
import { Icon } from '../Icons.tsx';

/**
 * The Journal's Places on the web (Batch N): the iPhone shows a map; here each place is a group
 * with its pages and an Apple Maps link, because a map would need a third-party script
 * (DECISIONS 304).
 */
export function PlacesList({ entries }: { entries: Rec<EntryData>[] }) {
  const { openEntry } = useDiary();
  const groups = placeGroups(entries);
  if (groups.length === 0) return <Empty icon="place" text="No places yet. Add one with the Place button when you write a page." />;
  return (
    <div className="places-list">
      {groups.map(({ place, entries: pages }) => (
        <section key={`${place.name}|${place.latitude ?? ''}|${place.longitude ?? ''}`} className="place-group glass" aria-label={place.name}>
          <header>
            <Icon name="place" />
            <span className="place-text">
              <h2 className="callout">{place.name}</h2>
              {place.address && <span className="caption ink3">{place.address}</span>}
            </span>
            <a className="caption place-open" href={appleMapsURL(place)} target="_blank" rel="noopener noreferrer">Apple Maps<span className="sr-only"> for {place.name} (opens a new tab)</span></a>
          </header>
          <ul>
            {pages.map((e) => (
              <li key={e.id}>
                <button onClick={() => openEntry(e.id)}>
                  <span className="caption ink3">{formatShort(e.data.dayKey)}</span>
                  <span>{e.data.title || 'Untitled'}</span>
                </button>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}
