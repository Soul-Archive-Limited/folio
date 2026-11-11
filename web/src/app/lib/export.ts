import { cleanPlace } from './place.ts';
/**
 * "Export as JSON + photos" on the web (Batch L), the same shape as the iPhone's DataExporter:
 * `Folio Export.json` (settings, categories, entries with Markdown bodies, tasks) and a
 * `Folio Photos/` folder, in one zip made in this tab and saved by the browser. Everything is
 * decrypted locally; nothing is sent anywhere.
 */
import type { DataKey } from './crypto.ts';
import { photoBytes } from './photos.ts';
import type { DiaryStore } from './store.ts';
import { zip, type ZipFile } from './zip.ts';

export async function exportDiary(store: DiaryStore, key: DataKey, includeTrash: boolean, progress: (done: number, total: number) => void): Promise<{ blob: Blob; missing: number }> {
  const trashed = store.trashed();
  const entries = [...store.entries(), ...(includeTrash ? trashed.entries : [])];
  const tasks = [...store.tasks(), ...store.tasks().flatMap((t) => store.subtasksOf(t.id)), ...(includeTrash ? trashed.tasks : [])];
  const categories = store.categories(includeTrash);
  const files: ZipFile[] = [];
  const photos = entries.flatMap((e) => store.photosOf(e.id).map((p, i) => ({ entry: e, photo: p, index: i })));
  const names = new Map<string, string[]>();
  let done = 0, missing = 0;
  for (const { entry, photo, index } of photos) {
    const bytes = await photoBytes(key, store.userId, photo.id, 'full') ?? await photoBytes(key, store.userId, photo.id, 'display');
    if (bytes) {
      const extension = bytes[0] === 0xff && bytes[1] === 0xd8 ? 'jpg' : 'heic';
      const name = `${entry.data.dayKey} ${entry.id.slice(0, 8)} ${index + 1}.${extension}`;
      files.push({ name: `Folio Photos/${name}`, data: bytes });
      names.set(entry.id, [...(names.get(entry.id) ?? []), name]);
    } else missing++;
    progress(++done, photos.length);
  }
  const json = {
    exportedAt: new Date().toISOString(),
    app: 'Folio (web)',
    settings: store.settings ? { displayName: store.settings.displayName, appearance: store.settings.appearance, writingFont: store.settings.writingFont, firstWeekday: store.settings.firstWeekday } : null,
    categories: categories.map((c) => ({ id: c.id, name: c.data.name, colorKey: c.data.colorKey, symbol: c.data.symbol, trashedAt: c.data.trashedAt })),
    entries: entries.map((e) => ({
      id: e.id, day: e.data.dayKey, minutesFromMidnight: e.data.minutesFromMidnight, title: e.data.title, bodyMarkdown: e.data.bodyMarkdown,
      categoryID: e.data.categoryID, mood: e.data.mood, place: cleanPlace(e.data.place), photos: names.get(e.id) ?? [], createdAt: e.data.createdAt, trashedAt: e.data.trashedAt,
    })),
    tasks: tasks.map((t) => ({
      id: t.id, title: t.data.title, notes: t.data.notes, day: t.data.dayKey, minutesFromMidnight: t.data.minutesFromMidnight, categoryID: t.data.categoryID,
      isCompleted: t.data.isCompleted, completedAt: t.data.completedAt, remindAt: t.data.remindAt, repeatRule: t.data.repeatRule, parentID: t.data.parentID, trashedAt: t.data.trashedAt,
    })),
  };
  files.unshift({ name: 'Folio Export.json', data: new TextEncoder().encode(JSON.stringify(json, null, 2)) });
  // Batch L review: never hand over a silently incomplete export.
  return { blob: zip(files), missing };
}

/** Hands a blob to the browser's own download (the person asked for it). */
export function save(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}
