/**
 * The JSON inside each record's ciphertext (DECISIONS 180), as `RecordPayload.swift`: keys
 * sorted, times in milliseconds since 1970, UUIDs as strings compared case-insensitively,
 * absent optionals left out. Unknown keys from a newer app are kept on edit.
 */

export interface EntryData {
  title: string;
  bodyMarkdown: string;
  dayKey: string;
  minutesFromMidnight?: number;
  categoryID?: string;
  createdAt: number;
  trashedAt?: number;
}

export interface PhotoData {
  entryID: string;
  sortIndex: number;
  pixelWidth: number;
  pixelHeight: number;
  createdAt: number;
}

export interface TaskData {
  title: string;
  notes?: string;
  dayKey?: string;
  minutesFromMidnight?: number;
  categoryID?: string;
  isCompleted: boolean;
  completedAt?: number;
  sortIndex: number;
  createdAt: number;
  trashedAt?: number;
  /** Batch I: floating local "YYYY-MM-DDTHH:mm"; each iPhone schedules its own reminder. */
  remindAt?: string;
  /** Batch I: JSON `RepeatRule` (see RepeatRule.swift). */
  repeatRule?: string;
  /** Batch I: the parent task of a subtask. */
  parentID?: string;
}

export interface CategoryData {
  name: string;
  colorKey: string;
  symbol?: string;
  sortIndex: number;
  createdAt: number;
  trashedAt?: number;
  unassignedIDs?: string[];
}

export interface SettingsData {
  displayName: string;
  appearance: 'system' | 'light' | 'dark' | string;
  writingFont: 'newYork' | 'sfPro' | string;
  firstWeekday?: number;
  defaultCategoryID?: string;
  createdAt: number;
  /** Batch I: "folio:07" (a Folio avatar), "photo" (avatarPhoto) or absent (monogram). */
  avatar?: string;
  /** Batch I: base64 of a 256 px JPEG (Swift `Data` encodes as base64). */
  avatarPhoto?: string;
}

export type SyncType = 'entry' | 'entryPhoto' | 'task' | 'category' | 'settings';
export interface DataFor { entry: EntryData; entryPhoto: PhotoData; task: TaskData; category: CategoryData; settings: SettingsData }

/** There's one settings record per account, always this id. */
export const SETTINGS_ID = '00000000-0000-4000-8000-000000000001';

/** JSON with sorted keys and no null/undefined values, like Swift's `.sortedKeys` encoder. */
export function encodePayload(data: object): string {
  const clean = Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined && value !== null).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)),
  );
  return JSON.stringify(clean);
}

export const decodePayload = <T>(text: string): T => JSON.parse(text) as T;

export const CATEGORY_COLORS = ['ember', 'coral', 'rose', 'plum', 'violet', 'indigo', 'ocean', 'teal', 'sage', 'olive', 'sand', 'graphite'] as const;
export const categoryColor = (key: string | undefined) => `var(--cat-${CATEGORY_COLORS.includes(key as never) ? key : 'graphite'})`;
