import assert from 'node:assert/strict';
import { test } from 'node:test';
import { encodePayload } from '../src/app/lib/payloads.ts';
import { appleMapsURL, cleanPlace, placeGroups, recentPlaces } from '../src/app/lib/place.ts';

// Batch N: the same rules as Place.swift's `validated()` and `mapsURL`.
test('cleanPlace trims, cuts to length and drops coordinates off the globe', () => {
  assert.equal(cleanPlace({ name: '   ' }), undefined);
  assert.equal(cleanPlace(null), undefined);
  assert.equal(cleanPlace('Tate'), undefined);
  const long = cleanPlace({ name: 'a'.repeat(300), address: '  ', latitude: 91, longitude: 10 })!;
  assert.equal(long.name.length, 120);
  assert.deepEqual(Object.keys(long), ['name']);
  assert.deepEqual(cleanPlace({ name: 'X', latitude: Number.NaN, longitude: 0 }), { name: 'X' });
  assert.deepEqual(cleanPlace({ name: ' Tate Modern ', address: 'Bankside, London', latitude: 51.5076, longitude: -0.0994, extra: 1 }),
    { address: 'Bankside, London', latitude: 51.5076, longitude: -0.0994, name: 'Tate Modern' });
});

test('the place in the payload has sorted keys, like Swift', () => {
  const json = encodePayload({ title: 'T', place: cleanPlace({ name: 'Kew', longitude: -0.29, latitude: 51.47, address: 'Richmond' }) });
  assert.equal(json, '{"place":{"address":"Richmond","latitude":51.47,"longitude":-0.29,"name":"Kew"},"title":"T"}');
});

test('Apple Maps link: a pin with coordinates, a search by name otherwise', () => {
  const pinned = appleMapsURL({ name: 'Tate Modern', latitude: 51.5076, longitude: -0.0994 });
  assert.ok(pinned.startsWith('https://maps.apple.com/?'));
  assert.ok(pinned.includes('ll=51.507600%2C-0.099400') && pinned.includes('q=Tate+Modern'));
  assert.ok(!appleMapsURL({ name: 'Café & bar' }).includes('ll='));
});

const rec = (id: string, place: unknown, updatedAt: number, dayKey = '2026-11-01', trashedAt?: number) =>
  ({ id, version: 1, updatedAt, data: { title: id, bodyMarkdown: '', dayKey, createdAt: 1, place, trashedAt } }) as never;

test('recent places: newest first, one per place, never trashed', () => {
  const list = [
    rec('a', { name: 'Tate Modern', latitude: 51.5076, longitude: -0.0994 }, 1),
    rec('b', { name: 'Kew Gardens', latitude: 51.4787, longitude: -0.2956 }, 2),
    rec('c', { name: 'tate modern', latitude: 51.50761, longitude: -0.09941 }, 3),
    rec('d', { name: 'Secret' }, 4, '2026-11-01', 5),
  ];
  assert.deepEqual(recentPlaces(list).map((p) => p.name), ['tate modern', 'Kew Gardens']);
});

test('place groups: pages at the same place together, most pages first', () => {
  const groups = placeGroups([
    rec('a', { name: 'Kew' }, 1, '2026-10-01'), rec('b', { name: 'Bath' }, 1, '2026-10-02'), rec('c', { name: 'kew' }, 1, '2026-10-03'), rec('d', undefined, 1),
  ]);
  assert.deepEqual(groups.map((g) => [g.place.name, g.entries.map((e) => e.id)]), [['Kew', ['c', 'a']], ['Bath', ['b']]]);
});
