import { createContext, useContext, useSyncExternalStore } from 'react';
import type { Me } from '../lib/api.ts';
import type { DataKey } from '../lib/crypto.ts';
import type { DiaryStore } from '../lib/store.ts';
import type { SyncEngine } from '../lib/sync.ts';

export type Tab = 'calendar' | 'journal' | 'todo' | 'profile';

export interface ComposerRequest { entryId?: string; dayKey?: string; categoryId?: string }
export interface TaskRequest { taskId?: string; dayKey?: string }
export interface Toast { id: number; text: string; action?: { label: string; run: () => void }; seconds?: number }

export interface Diary {
  me: Me;
  store: DiaryStore;
  engine: SyncEngine;
  key: DataKey;
  route: string;
  navigate: (path: string) => void;
  openComposer: (request?: ComposerRequest) => void;
  openTask: (request?: TaskRequest) => void;
  openEntry: (id: string) => void;
  toast: (text: string, action?: Toast['action'], seconds?: number) => void;
  showDay: (dayKey: string) => void;
  selectedDay: string;
  signOut: () => Promise<void>;
  lock: () => void;
}

export const DiaryContext = createContext<Diary | null>(null);

/** The diary, re-rendering whenever the store changes. */
export function useDiary(): Diary {
  const diary = useContext(DiaryContext);
  if (!diary) throw new Error('useDiary outside the diary');
  useSyncExternalStore(diary.store.subscribe, diary.store.getRevision);
  return diary;
}
