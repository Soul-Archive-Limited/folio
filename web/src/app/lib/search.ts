/**
 * Search, in memory only (Batch J): the same word rules as the iPhone (`SearchText.swift`,
 * pinned by `shared/search-fixtures.json`) over the decrypted diary the tab already holds.
 * Nothing is indexed on the server or stored in the browser.
 */
import { sameId } from './bytes.ts';
import { plainText } from './markdown.ts';
import type { DiaryStore, Rec } from './store.ts';
import type { EntryData, TaskData } from './payloads.ts';

const MARK = /\p{M}/u;
const WORD = /[\p{L}\p{N}]/u;

/** Han, kana: no spaces between words, so each character is a word of its own. */
export const isIdeographic = (cp: number) =>
  (cp >= 0x3040 && cp <= 0x30ff) || (cp >= 0x3400 && cp <= 0x4dbf) || (cp >= 0x4e00 && cp <= 0x9fff)
  || (cp >= 0xf900 && cp <= 0xfaff) || (cp >= 0x20000 && cp <= 0x2ffff);

/** Folded words: lower case, accents dropped from Latin letters only, other scripts whole;
 *  Chinese and Japanese characters one per word. */
export function words(text: string): string[] {
  const out: string[] = [];
  let current = '';
  let lastBaseIsLatin = false;
  for (const ch of text.normalize('NFD')) {
    if (MARK.test(ch)) {
      if (current && !lastBaseIsLatin) current += ch;
      continue;
    }
    const cp = ch.codePointAt(0) ?? 0;
    if (isIdeographic(cp)) {
      if (current) out.push(current);
      out.push(ch);
      current = '';
      lastBaseIsLatin = false;
    } else if (WORD.test(ch)) {
      lastBaseIsLatin = cp < 0x0250;
      current += ch.toLowerCase();
    } else if (current) {
      out.push(current);
      current = '';
    }
  }
  if (current) out.push(current);
  return out;
}

export interface SearchFilters {
  tasksOnly?: boolean;
  categories?: string[];
  hasPhotos?: boolean;
  from?: string;
  through?: string;
  status?: 'any' | 'open' | 'done';
}

export interface SearchDoc {
  id: string;
  kind: 'entry' | 'task';
  dayKey?: string;
  categoryID?: string;
  title: string;
  text: string;
  subtasks: string[];
  photoCount: number;
  firstPhotoID?: string;
  isCompleted: boolean;
  vocabulary: string[];
}

export const filtersActive = (f: SearchFilters) =>
  !!(f.categories?.length || f.hasPhotos || f.from || f.through || (f.status && f.status !== 'any'));

function vocabulary(parts: string[]): string[] {
  const set = new Set<string>();
  for (const part of parts) for (const w of words(part)) set.add(w);
  return [...set].sort();
}

/** Any word in the sorted vocabulary starting with `prefix` (binary search). */
export function hasPrefix(vocab: string[], prefix: string): boolean {
  let low = 0;
  let high = vocab.length;
  while (low < high) {
    const mid = (low + high) >> 1;
    if (vocab[mid]! < prefix) low = mid + 1; else high = mid;
  }
  return low < vocab.length && vocab[low]!.startsWith(prefix);
}

const cache = new WeakMap<DiaryStore, { revision: number; docs: SearchDoc[]; categoryWords: Map<string, string[]> }>();
const entryDocs = new WeakMap<Rec<EntryData>, SearchDoc>();

/** Documents for the store's current revision; unchanged entry records reuse their document. */
export function documents(store: DiaryStore) {
  const hit = cache.get(store);
  if (hit && hit.revision === store.revision) return hit;
  const docs: SearchDoc[] = [];
  for (const e of store.entries().sort((a, b) => b.data.dayKey.localeCompare(a.data.dayKey))) {
    const photos = store.photosOf(e.id);
    let doc = entryDocs.get(e);
    if (!doc || doc.photoCount !== photos.length) {
      const text = plainText(e.data.bodyMarkdown);
      doc = {
        id: e.id, kind: 'entry', dayKey: e.data.dayKey, categoryID: e.data.categoryID, title: e.data.title, text,
        subtasks: [], photoCount: photos.length, firstPhotoID: photos[0]?.id, isCompleted: false,
        // Batch N: the place's name and address match too.
        vocabulary: vocabulary([e.data.title, text, e.data.place?.name ?? '', e.data.place?.address ?? '']),
      };
      entryDocs.set(e, doc);
    }
    docs.push(doc);
  }
  for (const t of store.tasks().sort((a, b) => (b.data.dayKey ?? '').localeCompare(a.data.dayKey ?? ''))) {
    docs.push(taskDoc(t, store.subtasksOf(t.id).map((s) => s.data.title)));
  }
  const categoryWords = new Map(store.categories().map((c) => [c.id.toLowerCase(), words(c.data.name)]));
  const built = { revision: store.revision, docs, categoryWords };
  cache.set(store, built);
  return built;
}

function taskDoc(t: Rec<TaskData>, subtasks: string[]): SearchDoc {
  return {
    id: t.id, kind: 'task', dayKey: t.data.dayKey, categoryID: t.data.categoryID, title: t.data.title,
    text: t.data.notes ?? '', subtasks, photoCount: 0, isCompleted: t.data.isCompleted,
    vocabulary: vocabulary([t.data.title, t.data.notes ?? '', ...subtasks]),
  };
}

function admits(doc: SearchDoc, f: SearchFilters): boolean {
  const status = f.status ?? 'any';
  if (doc.kind === 'entry') {
    if (f.tasksOnly || status !== 'any') return false;
    if (f.hasPhotos && doc.photoCount === 0) return false;
  } else {
    if (f.hasPhotos) return false;
    if (status === 'open' && doc.isCompleted) return false;
    if (status === 'done' && !doc.isCompleted) return false;
  }
  if (f.categories?.length && !f.categories.some((c) => sameId(c, doc.categoryID))) return false;
  if (f.from || f.through) {
    if (!doc.dayKey) return false;
    if (f.from && doc.dayKey < f.from) return false;
    if (f.through && doc.dayKey > f.through) return false;
  }
  return true;
}

export function search(store: DiaryStore, text: string, filters: SearchFilters = {}): SearchDoc[] {
  const terms = [...new Set(words(text))];
  if (!terms.length && !filtersActive(filters)) return [];
  const { docs, categoryWords } = documents(store);
  const categoryHits = new Map(terms.map((term) => [term,
    new Set([...categoryWords].filter(([, ws]) => ws.some((w) => w.startsWith(term))).map(([id]) => id))]));
  return docs.filter((doc) => admits(doc, filters) && terms.every((term) =>
    hasPrefix(doc.vocabulary, term) || (!!doc.categoryID && !!categoryHits.get(term)?.has(doc.categoryID.toLowerCase()))));
}

/** Splits `text` into plain and matched parts for highlighting (word starts only). */
export function highlight(text: string, terms: string[]): { text: string; match: boolean }[] {
  if (!terms.length) return [{ text, match: false }];
  const parts: { text: string; match: boolean }[] = [];
  // Words; a Chinese or Japanese character is a word of its own (as in `words`).
  const re = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u{20000}-\u{2ffff}]|(?:(?![\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u{20000}-\u{2ffff}])[\p{L}\p{N}\p{M}])+/gu;
  let cursor = 0;
  for (const m of text.matchAll(re)) {
    const folded = words(m[0])[0] ?? '';
    const term = terms.find((t) => folded.startsWith(t));
    if (!term) continue;
    // Grow the original slice until its folded form covers the term.
    let end = m.index! + 1;
    while (end < m.index! + m[0].length && (words(text.slice(m.index!, end))[0] ?? '').length < term.length) end++;
    if (m.index! > cursor) parts.push({ text: text.slice(cursor, m.index!), match: false });
    parts.push({ text: text.slice(m.index!, end), match: true });
    cursor = end;
  }
  if (cursor < text.length) parts.push({ text: text.slice(cursor), match: false });
  return parts;
}

/** A window starting a little before the first match. */
export function snippet(text: string, terms: string[], lead = 36): string {
  const flat = text.replace(/\n/g, ' ').trim();
  const first = highlight(flat, terms).findIndex((p) => p.match);
  if (first < 0) return flat;
  const offset = highlight(flat, terms).slice(0, first).reduce((n, p) => n + p.text.length, 0);
  if (offset <= lead) return flat;
  let start = offset - lead;
  const space = flat.indexOf(' ', start);
  if (space >= 0 && space < offset) start = space + 1;
  return '…' + flat.slice(start);
}
