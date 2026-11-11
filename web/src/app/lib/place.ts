import type { EntryData, PlaceData } from './payloads.ts';
import type { Rec } from './store.ts';

/**
 * Places on entries (Batch N), as `Place.swift`. The web app adds a place by name only: map
 * search would need a third-party script or an Apple Maps token on our server (DECISIONS 304).
 * A place's coordinates come from the iPhone and are kept as they are.
 */
export const MAX_PLACE_NAME = 120;
export const MAX_PLACE_ADDRESS = 200;

/** A clean copy, or undefined when there's no name — the same rules as `Place.validated()`. */
export function cleanPlace(raw: unknown): PlaceData | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const r = raw as Record<string, unknown>;
  const name = typeof r.name === 'string' ? r.name.trim().slice(0, MAX_PLACE_NAME) : '';
  if (!name) return undefined;
  const address = typeof r.address === 'string' ? r.address.trim().slice(0, MAX_PLACE_ADDRESS) : '';
  const lat = r.latitude, lon = r.longitude;
  const onGlobe = typeof lat === 'number' && typeof lon === 'number' && Number.isFinite(lat) && Number.isFinite(lon)
    && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  // Sorted keys, undefined left out (encodePayload only sorts the top level).
  const place: PlaceData = { ...(address ? { address } : {}), ...(onGlobe ? { latitude: lat, longitude: lon } : {}), name } as PlaceData;
  return place;
}

/** Apple Maps: a pin at the coordinate, or a search by name. Opens maps.apple.com — no script. */
export function appleMapsURL(place: PlaceData): string {
  const url = new URL('https://maps.apple.com/');
  url.searchParams.set('q', place.name);
  if (place.latitude !== undefined && place.longitude !== undefined) url.searchParams.set('ll', `${place.latitude.toFixed(6)},${place.longitude.toFixed(6)}`);
  return url.toString();
}

export const placeLine = (place: PlaceData) => [place.name, place.address].filter(Boolean).join(' · ');

const same = (a: PlaceData, b: PlaceData) => a.name.toLowerCase() === b.name.toLowerCase()
  && (a.latitude === undefined) === (b.latitude === undefined)
  && (a.latitude === undefined || (Math.abs(a.latitude - b.latitude!) < 0.0005 && Math.abs(a.longitude! - b.longitude!) < 0.0005));

/** Recently used places, newest first, one per place, from the diary itself. */
export function recentPlaces(entries: Rec<EntryData>[], limit = 6): PlaceData[] {
  const out: PlaceData[] = [];
  for (const e of [...entries].sort((a, b) => b.updatedAt - a.updatedAt)) {
    const p = cleanPlace(e.data.place);
    if (!p || e.data.trashedAt || out.some((o) => same(o, p))) continue;
    out.push(p);
    if (out.length === limit) break;
  }
  return out;
}

/** Pages grouped by place, for the Journal's Places list: most pages first. */
export function placeGroups(entries: Rec<EntryData>[]): { place: PlaceData; entries: Rec<EntryData>[] }[] {
  const groups: { place: PlaceData; entries: Rec<EntryData>[] }[] = [];
  for (const e of entries) {
    const p = cleanPlace(e.data.place);
    if (!p || e.data.trashedAt) continue;
    const group = groups.find((g) => same(g.place, p));
    if (group) group.entries.push(e); else groups.push({ place: p, entries: [e] });
  }
  for (const g of groups) g.entries.sort((a, b) => (a.data.dayKey < b.data.dayKey ? 1 : -1));
  return groups.sort((a, b) => b.entries.length - a.entries.length || (a.entries[0]!.data.dayKey < b.entries[0]!.data.dayKey ? 1 : -1));
}
