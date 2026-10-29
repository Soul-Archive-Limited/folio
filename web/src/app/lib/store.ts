/**
 * The web app's diary, decrypted and held in memory only (SPEC §11.3). Every edit is
 * applied at once (optimistic) and remembered with what it replaced, so a push the server
 * refuses — or one that can't get through — rolls back (SPEC §11.3). The sync engine
 * (`sync.ts`) moves records in and out.
 */
import { newId, sameId } from './bytes.ts';
import { type CategoryData, type DataFor, type EntryData, type PhotoData, type SettingsData, SETTINGS_ID, type SyncType, type TaskData } from './payloads.ts';

export interface Rec<T> { id: string; version: number | null; updatedAt: number; data: T }
type AnyRec = Rec<DataFor[SyncType]>;

export interface Pending {
  type: SyncType;
  id: string;
  /** What this record was before the edit (undefined = it didn't exist). */
  previous: AnyRec | undefined;
  deleted: boolean;
  /** Photo records wait until their three renditions are in R2. */
  waitingForBlob?: boolean;
}

export const DAY_MS = 86_400_000;
export const TRASH_DAYS = 30;

const key = (id: string) => id.toLowerCase();

export class DiaryStore {
  readonly maps: { [K in SyncType]: Map<string, Rec<DataFor[K]>> } = {
    entry: new Map(), entryPhoto: new Map(), task: new Map(), category: new Map(), settings: new Map(),
  };
  /** Permanently deleted ids; never recreated (SPEC §10.5). */
  readonly tombstones = new Set<string>();
  readonly pending = new Map<string, Pending>();
  revision = 0;
  private listeners = new Set<() => void>();
  onChange: (() => void) | null = null;

  constructor(readonly userId: string) {}

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };
  getRevision = () => this.revision;

  emit() {
    this.revision++;
    this.listeners.forEach((l) => l());
  }

  get<K extends SyncType>(type: K, id: string): Rec<DataFor[K]> | undefined {
    return this.maps[type].get(key(id)) as Rec<DataFor[K]> | undefined;
  }

  typeOf(id: string): SyncType | undefined {
    return (Object.keys(this.maps) as SyncType[]).find((t) => this.maps[t].has(key(id)));
  }

  // MARK: Local edits (optimistic)

  /** Creates or updates a record; returns its id. Unknown keys from a newer app are kept. */
  put<K extends SyncType>(type: K, data: Partial<DataFor[K]>, id?: string, options: { waitingForBlob?: boolean; silent?: boolean } = {}): string {
    const recordId = id ?? newId();
    const existing = this.get(type, recordId);
    if (this.tombstones.has(key(recordId))) return recordId;
    const merged = { ...(existing?.data ?? {}), ...data } as DataFor[K];
    for (const k of Object.keys(merged) as (keyof DataFor[K])[]) if (merged[k] === undefined) delete merged[k];
    this.remember(type, existing?.id ?? recordId, existing, false, options.waitingForBlob);
    this.maps[type].set(key(recordId), { id: existing?.id ?? recordId, version: existing?.version ?? null, updatedAt: Date.now(), data: merged } as never);
    if (!options.silent) this.changed();
    return existing?.id ?? recordId;
  }

  /** Permanent delete (Delete now, Empty, the 30-day purge): a tombstone that syncs. */
  destroy(type: SyncType, id: string) {
    const existing = this.get(type, id);
    if (!existing) return;
    this.remember(type, existing.id, existing, true);
    this.maps[type].delete(key(id));
    this.tombstones.add(key(id));
    this.changed();
  }

  private remember(type: SyncType, id: string, previous: AnyRec | undefined, deleted: boolean, waitingForBlob?: boolean) {
    const already = this.pending.get(key(id));
    // Keep the oldest "previous": rolling back undoes the whole unsent run of edits.
    this.pending.set(key(id), { type, id, previous: already ? already.previous : previous, deleted, waitingForBlob: waitingForBlob ?? already?.waitingForBlob });
  }

  private changed() {
    this.emit();
    this.onChange?.();
  }

  blobUploaded(photoId: string) {
    const p = this.pending.get(key(photoId));
    if (p) p.waitingForBlob = false;
  }

  /** The server refused or we gave up: put these records back as they were. */
  rollback(ids: string[]) {
    for (const id of ids) {
      const p = this.pending.get(key(id));
      if (!p) continue;
      this.pending.delete(key(id));
      if (p.deleted) this.tombstones.delete(key(id));
      if (p.previous) this.maps[p.type].set(key(id), p.previous as never);
      else this.maps[p.type].delete(key(id));
    }
    this.emit();
  }

  // MARK: From the server

  applyRemote(type: SyncType, id: string, version: number, updatedAt: number, data: DataFor[SyncType] | null) {
    if (data === null) {
      for (const map of Object.values(this.maps)) map.delete(key(id));
      this.tombstones.add(key(id));
      this.pending.delete(key(id));
      return;
    }
    if (this.tombstones.has(key(id))) return;
    const local = this.maps[type].get(key(id));
    // A newer unsent local edit wins (last writer wins); it pushes next.
    if (this.pending.has(key(id)) && local && local.updatedAt > updatedAt) {
      local.version = version;
      return;
    }
    this.pending.delete(key(id));
    this.maps[type].set(key(id), { id: local?.id ?? id, version, updatedAt, data } as never);
  }

  acknowledge(id: string, version: number, sentUpdatedAt: number) {
    const rec = this.maps[this.typeOf(id) ?? 'entry'].get(key(id));
    if (rec) rec.version = version;
    // Edited again while the push was in flight: stays pending, now based on this version.
    if (rec && rec.updatedAt > sentUpdatedAt) {
      const p = this.pending.get(key(id));
      if (p) p.previous = { ...rec };
      return;
    }
    this.pending.delete(key(id));
  }

  // MARK: Queries (live = not in Recently Deleted)

  get settings(): SettingsData | undefined { return this.get('settings', SETTINGS_ID)?.data; }
  categories(includeTrash = false): Rec<CategoryData>[] {
    return [...this.maps.category.values()].filter((c) => includeTrash || !c.data.trashedAt).sort((a, b) => a.data.sortIndex - b.data.sortIndex || a.data.createdAt - b.data.createdAt);
  }
  category(id: string | undefined): Rec<CategoryData> | undefined {
    if (!id) return undefined;
    const c = this.get('category', id);
    return c && !c.data.trashedAt ? c : undefined;
  }
  entries(): Rec<EntryData>[] { return [...this.maps.entry.values()].filter((e) => !e.data.trashedAt); }
  tasks(): Rec<TaskData>[] { return [...this.maps.task.values()].filter((t) => !t.data.trashedAt); }
  photosOf(entryId: string): Rec<PhotoData>[] {
    return [...this.maps.entryPhoto.values()].filter((p) => sameId(p.data.entryID, entryId)).sort((a, b) => a.data.sortIndex - b.data.sortIndex);
  }
  trashed() {
    return {
      entries: [...this.maps.entry.values()].filter((e) => e.data.trashedAt),
      tasks: [...this.maps.task.values()].filter((t) => t.data.trashedAt),
      categories: [...this.maps.category.values()].filter((c) => c.data.trashedAt),
    };
  }

  // MARK: Recently Deleted (SPEC §5.2)

  trash(type: 'entry' | 'task', id: string) {
    this.put(type, { trashedAt: Date.now() } as never, id);
  }

  restore(type: 'entry' | 'task', id: string) {
    this.put(type, { trashedAt: undefined } as never, id);
  }

  /** Un-assigns the category's entries and tasks and remembers which (so restore re-links). */
  trashCategory(id: string) {
    const unassigned: string[] = [];
    for (const type of ['entry', 'task'] as const) {
      for (const rec of this.maps[type].values()) {
        if (sameId(rec.data.categoryID, id)) {
          unassigned.push(rec.id);
          this.put(type, { categoryID: undefined } as never, rec.id, { silent: true });
        }
      }
    }
    this.put('category', { trashedAt: Date.now(), unassignedIDs: unassigned }, id);
  }

  restoreCategory(id: string) {
    const rec = this.get('category', id);
    if (!rec) return;
    const names = new Set(this.categories().map((c) => c.data.name.toLowerCase()));
    let name = rec.data.name;
    for (let n = 2; names.has(name.toLowerCase()); n++) name = `${rec.data.name} ${n}`;
    for (const itemId of rec.data.unassignedIDs ?? []) {
      const type = this.typeOf(itemId);
      if ((type === 'entry' || type === 'task') && !this.get(type, itemId)!.data.categoryID) {
        this.put(type, { categoryID: rec.id } as never, itemId, { silent: true });
      }
    }
    this.put('category', { trashedAt: undefined, unassignedIDs: undefined, name }, id);
  }

  /** Delete now: the entry and its photos, or a task, or a category, for good. */
  destroyItem(type: 'entry' | 'task' | 'category', id: string): string[] {
    const photoIds = type === 'entry' ? this.photosOf(id).map((p) => p.id) : [];
    for (const photoId of photoIds) this.destroy('entryPhoto', photoId);
    this.destroy(type, id);
    return photoIds;
  }

  /** Items in Recently Deleted for more than 30 days (SPEC §5.2); returns purged photo ids. */
  purgeExpired(now = Date.now()): string[] {
    const cutoff = now - TRASH_DAYS * DAY_MS;
    const photos: string[] = [];
    const t = this.trashed();
    for (const e of t.entries) if (e.data.trashedAt! < cutoff) photos.push(...this.destroyItem('entry', e.id));
    for (const k of t.tasks) if (k.data.trashedAt! < cutoff) this.destroyItem('task', k.id);
    for (const c of t.categories) if (c.data.trashedAt! < cutoff) this.destroyItem('category', c.id);
    return photos;
  }
}

export const daysLeft = (trashedAt: number, now = Date.now()) => Math.max(0, TRASH_DAYS - Math.floor((now - trashedAt) / DAY_MS));
