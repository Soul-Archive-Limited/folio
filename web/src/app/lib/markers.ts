/** Day markers for the calendar (SPEC §6.2), as `DayMarker.swift`. */
import { sameId } from './bytes.ts';
import type { EntryData, TaskData } from './payloads.ts';
import type { DiaryStore, Rec } from './store.ts';

export interface DayIndex { entries: Rec<EntryData>[]; tasks: Rec<TaskData>[] }

export interface DayMarker {
  entryCount: number;
  /** The latest entry's first photo. */
  thumbnailPhotoId?: string;
  /** Entries beyond the one whose photo is shown ("+2"). */
  extraEntryCount: number;
  /** Up to 3 category ids (undefined = uncategorised) for entries without photos. */
  dots: (string | undefined)[];
  openTasks: number;
  doneTasks: number;
  categoryIds: Set<string>;
}

export const byTimeInDay = (a: Rec<EntryData>, b: Rec<EntryData>) =>
  (a.data.minutesFromMidnight ?? -1) - (b.data.minutesFromMidnight ?? -1) || a.data.createdAt - b.data.createdAt;

/** Every live entry and dated task by day, rebuilt when the store changes. */
export function indexByDay(store: DiaryStore): Map<string, DayIndex> {
  const index = new Map<string, DayIndex>();
  const at = (day: string) => {
    let slot = index.get(day);
    if (!slot) index.set(day, (slot = { entries: [], tasks: [] }));
    return slot;
  };
  for (const e of store.entries()) at(e.data.dayKey).entries.push(e);
  for (const t of store.tasks()) if (t.data.dayKey) at(t.data.dayKey).tasks.push(t);
  for (const slot of index.values()) {
    slot.entries.sort(byTimeInDay);
    slot.tasks.sort((a, b) => (a.data.minutesFromMidnight ?? -1) - (b.data.minutesFromMidnight ?? -1) || a.data.sortIndex - b.data.sortIndex);
  }
  return index;
}

export function markerFor(store: DiaryStore, day: DayIndex | undefined): DayMarker {
  const marker: DayMarker = { entryCount: 0, extraEntryCount: 0, dots: [], openTasks: 0, doneTasks: 0, categoryIds: new Set() };
  if (!day) return marker;
  marker.entryCount = day.entries.length;
  for (const entry of [...day.entries].reverse()) {
    const photo = store.photosOf(entry.id)[0];
    if (photo) {
      marker.thumbnailPhotoId = photo.id;
      marker.extraEntryCount = day.entries.length - 1;
      break;
    }
  }
  for (const entry of day.entries) {
    const category = store.category(entry.data.categoryID);
    if (category) marker.categoryIds.add(category.id.toLowerCase());
    if (!store.photosOf(entry.id).length && marker.dots.length < 3) marker.dots.push(category?.id);
  }
  for (const task of day.tasks) {
    if (task.data.isCompleted) marker.doneTasks++;
    else marker.openTasks++;
    const category = store.category(task.data.categoryID);
    if (category) marker.categoryIds.add(category.id.toLowerCase());
  }
  return marker;
}

export const matchesFilter = (marker: DayMarker, filter: string | null) => !filter || marker.categoryIds.has(filter.toLowerCase());
export { sameId };
