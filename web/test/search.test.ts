// Search (Batch J): the same word rules as SearchText.swift, pinned by shared/search-fixtures.json.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { hasPrefix, highlight, search, snippet, words } from '../src/app/lib/search.ts';
import type { DiaryStore } from '../src/app/lib/store.ts';

// store.ts uses TypeScript syntax Node can't strip, so a small stand-in with the same reads.
type Data = Record<string, unknown> & { trashedAt?: number; parentID?: string; entryID?: string };
class FakeStore {
  revision = 0;
  private recs: { type: string; id: string; data: Data }[] = [];
  put(type: string, data: Data, _id?: string, _o?: unknown) {
    const id = crypto.randomUUID();
    this.recs.push({ type, id, data });
    this.revision++;
    return id;
  }
  emit() { this.revision++; }
  private of(type: string) { return this.recs.filter((r) => r.type === type && !r.data.trashedAt); }
  entries() { return this.of('entry'); }
  tasks() { return this.of('task').filter((t) => !t.data.parentID); }
  subtasksOf(id: string) { return this.of('task').filter((t) => t.data.parentID === id); }
  categories() { return this.of('category'); }
  photosOf(id: string) { return this.of('entryPhoto').filter((p) => p.data.entryID === id); }
}
const newStore = () => new FakeStore() as unknown as DiaryStore & FakeStore;

const fixtures = JSON.parse(readFileSync(new URL('../../shared/search-fixtures.json', import.meta.url), 'utf8')) as { cases: { input: string; words: string[] }[] };

test('word rules match the shared fixtures', () => {
  for (const c of fixtures.cases) assert.deepEqual(words(c.input), c.words, c.input);
});

test('prefix lookup and highlights at word starts only', () => {
  assert.ok(hasPrefix(['cafe', 'river'], 'riv'));
  assert.ok(!hasPrefix(['cafe', 'river'], 'ive'));
  const parts = highlight('Rivers and the riverside', ['river']);
  assert.deepEqual(parts.filter((p) => p.match).map((p) => p.text), ['River', 'river']);
  assert.deepEqual(highlight('Un café crème', ['creme']).filter((p) => p.match).map((p) => p.text), ['crème']);
  assert.ok(snippet('filler words here '.repeat(10) + 'the lighthouse', ['lighthouse']).startsWith('…'));
});

test('finds titles, text, categories, tasks and subtasks; filters', () => {
  const store = newStore();
  const travel = store.put('category', { name: 'Travel', colorKey: 'ocean', sortIndex: 0, createdAt: 0 });
  store.put('entry', { title: 'Lisbon', bodyMarkdown: 'Trams and **pastéis**', dayKey: '2025-05-02', categoryID: travel, createdAt: 0 });
  store.put('entry', { title: 'Quiet day', bodyMarkdown: 'Read by the window', dayKey: '2026-01-10', createdAt: 0 });
  store.put('entry', { title: 'Lisbon again', bodyMarkdown: '', dayKey: '2026-02-01', createdAt: 0, trashedAt: 1 });
  const pack = store.put('task', { title: 'Pack bags', dayKey: '2026-10-20', isCompleted: false, sortIndex: 0, createdAt: 0 });
  store.put('task', { title: 'Passport', parentID: pack, isCompleted: false, sortIndex: 1, createdAt: 0 });
  store.put('task', { title: 'Plan done', isCompleted: true, sortIndex: 2, createdAt: 0 });
  const titles = (q: string, f = {}) => search(store, q, f).map((d) => d.title);
  assert.deepEqual(titles('lisbon'), ['Lisbon']);
  assert.deepEqual(titles('pasteis'), ['Lisbon']);
  assert.deepEqual(titles('travel'), ['Lisbon']);
  assert.deepEqual(titles('window read'), ['Quiet day']);
  assert.deepEqual(titles('passp'), ['Pack bags']);
  assert.deepEqual(titles('', { status: 'done' }), ['Plan done']);
  assert.deepEqual(titles('', { categories: [travel] }), ['Lisbon']);
  assert.deepEqual(titles('', { from: '2026-01-01', through: '2026-12-31' }), ['Quiet day', 'Pack bags']);
  assert.deepEqual(titles('p', { tasksOnly: true }), ['Pack bags', 'Plan done']);
  assert.deepEqual(titles(''), []);
});

test('10,000 entries: a query is fast once the documents are built', () => {
  const store = newStore();
  const vocab = ['morning', 'river', 'coffee', 'train', 'letter', 'garden', 'harbour', 'bridge', 'lamp', 'market'];
  let seed = 7;
  const next = () => (seed = (seed * 1103515245 + 12345) % 2147483648);
  for (let i = 0; i < 10_000; i++) {
    const body = Array.from({ length: 60 }, () => vocab[next() % vocab.length]).join(' ');
    store.put('entry', { title: `Day ${i}`, bodyMarkdown: body, dayKey: `20${String(10 + (i % 15)).padStart(2, '0')}-01-01`, createdAt: 0 }, undefined, { silent: true });
  }
  store.emit();
  search(store, 'warm'); // build once
  const t = performance.now();
  const hits = search(store, 'harb bridge').length;
  assert.ok(hits > 0);
  assert.ok(performance.now() - t < 100, `query took ${performance.now() - t} ms`);
});
