/**
 * Keeps the in-memory diary and the account in step (SPEC §10.5, §11.3): one full pull on
 * unlock, a push ~0.4 s after each edit, the live socket while the tab is visible (its first
 * message is the cursor; a newer cursor means pull), and a pull when the tab regains focus.
 * Edits that the server refuses, or that can't get through after a few tries, roll back.
 */
import { ApiError, api, friendly, type Remote } from './api.ts';
import { fromUtf8, utf8 } from './bytes.ts';
import { openRecord, sealRecord, type DataKey, type RecordType } from './crypto.ts';
import { decodePayload, encodePayload, type DataFor, type SyncType } from './payloads.ts';
import { deletePhotoBlobs, type PreparedPhoto, uploadPhoto } from './photos.ts';
import { DiaryStore } from './store.ts';

const SYNC_TYPES = new Set<string>(['entry', 'entryPhoto', 'task', 'category', 'settings']);
const MAX_CHANGES = 200;
const MAX_BYTES = 700_000;
const MAX_TRIES = 4;

export type SyncStatus = 'upToDate' | 'syncing' | 'offline' | 'error';

export class SyncEngine {
  status: SyncStatus = 'syncing';
  lastSynced: number | null = null;
  loaded = false;
  cursor = 0;
  onProblem: ((message: string) => void) | null = null;
  onSignedOut: (() => void) | null = null;

  private socket: WebSocket | null = null;
  private ping: ReturnType<typeof setInterval> | undefined;
  private pushTimer: ReturnType<typeof setTimeout> | undefined;
  private retryTimer: ReturnType<typeof setTimeout> | undefined;
  private running: Promise<void> | null = null;
  private again = { pull: false, push: false };
  private tries = 0;
  private stopped = false;
  private photoQueue = new Map<string, PreparedPhoto>();
  private uploading = false;

  constructor(readonly store: DiaryStore, readonly key: DataKey) {
    store.onChange = () => this.schedulePush();
  }

  get userId() { return this.store.userId; }

  async start() {
    await this.run(true, false);
    this.loaded = true;
    const purged = this.store.purgeExpired();
    purged.forEach((id) => void deletePhotoBlobs(id));
    this.store.emit();
    document.addEventListener('visibilitychange', this.visibility);
    window.addEventListener('focus', this.focus);
    window.addEventListener('online', this.focus);
    if (document.visibilityState === 'visible') this.openSocket();
  }

  stop() {
    this.stopped = true;
    clearTimeout(this.pushTimer);
    clearTimeout(this.retryTimer);
    this.closeSocket();
    document.removeEventListener('visibilitychange', this.visibility);
    window.removeEventListener('focus', this.focus);
    window.removeEventListener('online', this.focus);
    this.store.onChange = null;
  }

  syncNow() { void this.run(true, true); }

  private visibility = () => {
    if (document.visibilityState === 'visible') {
      this.openSocket();
      void this.run(true, true);
    } else {
      this.closeSocket();
    }
  };
  private focus = () => void this.run(true, true);

  private schedulePush() {
    clearTimeout(this.pushTimer);
    this.setStatus('syncing');
    this.pushTimer = setTimeout(() => void this.run(false, true), 400);
  }

  /** Queues a photo's renditions; its record pushes once they're in R2. */
  addPhoto(photoId: string, photo: PreparedPhoto) {
    this.photoQueue.set(photoId.toLowerCase(), photo);
    void this.uploadPhotos();
  }

  private async uploadPhotos() {
    if (this.uploading) return;
    this.uploading = true;
    try {
      for (const [id, photo] of this.photoQueue) {
        try {
          await uploadPhoto(this.key, this.userId, id, photo);
          this.photoQueue.delete(id);
          this.store.blobUploaded(id);
          this.schedulePush();
        } catch (error) {
          this.photoQueue.delete(id);
          this.store.rollback([id]);
          this.onProblem?.(error instanceof ApiError ? friendly(error) : "Couldn't upload a photo.");
        }
      }
    } finally {
      this.uploading = false;
      if (this.photoQueue.size) void this.uploadPhotos();
    }
  }

  /** One pass at a time; requests made meanwhile run once it finishes. */
  private async run(pull: boolean, push: boolean): Promise<void> {
    if (this.stopped) return;
    if (this.running) {
      this.again.pull ||= pull;
      this.again.push ||= push;
      return this.running;
    }
    this.running = (async () => {
      try {
        this.setStatus('syncing');
        if (pull) await this.pull();
        if (push) await this.push();
        this.tries = 0;
        this.lastSynced = Date.now();
        this.setStatus([...this.store.pending.values()].some((p) => !p.waitingForBlob) ? 'syncing' : 'upToDate');
      } catch (error) {
        this.failed(error);
      } finally {
        this.running = null;
      }
      if (this.again.pull || this.again.push) {
        const next = this.again;
        this.again = { pull: false, push: false };
        await this.run(next.pull, next.push);
      }
    })();
    return this.running;
  }

  private failed(error: unknown) {
    if (error instanceof ApiError && error.status === 401) {
      this.onSignedOut?.();
      return;
    }
    const retryable = !(error instanceof ApiError) || error.isRetryable;
    this.tries++;
    if (retryable && this.tries < MAX_TRIES) {
      this.setStatus(error instanceof ApiError && error.isNetwork ? 'offline' : 'syncing');
      const wait = error instanceof ApiError && error.retryAfter ? error.retryAfter * 1000 : Math.min(2000 * 2 ** this.tries, 30_000) * (0.75 + Math.random() / 2);
      this.retryTimer = setTimeout(() => void this.run(true, true), wait);
      return;
    }
    // Optimistic edits that won't go through come back out (SPEC §11.3).
    const unsent = [...this.store.pending.values()].filter((p) => !p.waitingForBlob).map((p) => p.id);
    if (unsent.length) {
      this.store.rollback(unsent);
      this.onProblem?.(`${friendly(error)} Your last change was undone.`);
    }
    this.tries = 0;
    this.setStatus(error instanceof ApiError && error.isNetwork ? 'offline' : 'error');
  }

  private setStatus(status: SyncStatus) {
    if (this.status === status) return;
    this.status = status;
    this.store.emit();
  }

  // MARK: Pull

  private async pull() {
    let more = true;
    while (more) {
      const page = await api<{ changes: Remote[]; cursor: number; hasMore: boolean }>('GET', `sync/pull?since=${this.cursor}&limit=500`);
      for (const remote of page.changes) await this.apply(remote);
      this.cursor = page.cursor;
      more = page.hasMore;
      this.store.emit();
    }
  }

  private async apply(remote: Remote) {
    if (!SYNC_TYPES.has(remote.type)) return;
    const type = remote.type as SyncType;
    if (remote.deleted) {
      this.store.applyRemote(type, remote.id, remote.version, remote.clientUpdatedAt, null);
      return;
    }
    try {
      const plain = await openRecord(this.key, remote.ciphertext, remote.nonce, remote.id, type as RecordType, this.userId);
      this.store.applyRemote(type, remote.id, remote.version, remote.clientUpdatedAt, decodePayload<DataFor[SyncType]>(fromUtf8(plain)));
    } catch {
      // Wrong key or tampered: skipped, never shown (no details logged).
    }
  }

  // MARK: Push

  private async push() {
    const ready = [...this.store.pending.values()].filter((p) => !p.waitingForBlob);
    if (!ready.length) return;
    const changes: { change: Record<string, unknown>; sentUpdatedAt: number; id: string }[] = [];
    for (const p of ready) {
      const rec = this.store.get(p.type, p.id);
      if (p.deleted || !rec) {
        changes.push({ id: p.id, sentUpdatedAt: Date.now(), change: { id: p.id, type: p.type, ciphertext: '', nonce: '', clientUpdatedAt: Date.now(), baseVersion: p.previous?.version ?? null, deleted: true } });
        continue;
      }
      const sealed = await sealRecord(this.key, utf8.encode(encodePayload(rec.data)), rec.id, p.type as RecordType, this.userId);
      changes.push({ id: rec.id, sentUpdatedAt: rec.updatedAt, change: { id: rec.id, type: p.type, ...sealed, clientUpdatedAt: Math.round(rec.updatedAt), baseVersion: rec.version, deleted: false } });
    }
    for (const batch of batches(changes)) {
      const result = await api<{ accepted: { id: string; version: number }[]; conflicts: Remote[]; cursor: number }>('POST', 'sync/push', { changes: batch.map((c) => c.change) });
      const sent = new Map(batch.map((c) => [c.id.toLowerCase(), c.sentUpdatedAt]));
      for (const a of result.accepted) this.store.acknowledge(a.id, a.version, sent.get(a.id.toLowerCase()) ?? 0);
      // The server copy won (newer edit elsewhere, or deleted): take it.
      for (const conflict of result.conflicts) {
        this.store.pending.delete(conflict.id.toLowerCase());
        await this.apply(conflict);
      }
      this.store.emit();
    }
  }

  // MARK: Live socket

  private openSocket() {
    if (this.socket || this.stopped) return;
    const socket = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/api/live`);
    this.socket = socket;
    socket.onmessage = (event) => {
      if (event.data === 'pong') return;
      try {
        const message = JSON.parse(String(event.data)) as { cursor?: number };
        if (typeof message.cursor === 'number' && message.cursor > this.cursor) void this.run(true, false);
      } catch { /* not for us */ }
    };
    socket.onclose = () => {
      clearInterval(this.ping);
      if (this.socket === socket) this.socket = null;
      // Reconnect while visible (e.g. after a network blip), gently.
      if (!this.stopped && document.visibilityState === 'visible') setTimeout(() => this.openSocket(), 5000 + Math.random() * 5000);
    };
    this.ping = setInterval(() => socket.readyState === WebSocket.OPEN && socket.send('ping'), 30_000);
  }

  private closeSocket() {
    clearInterval(this.ping);
    const socket = this.socket;
    this.socket = null;
    socket?.close();
  }
}

function batches<T extends { change: Record<string, unknown> }>(items: T[]): T[][] {
  const out: T[][] = [];
  let current: T[] = [];
  let bytes = 0;
  for (const item of items) {
    const size = String(item.change.ciphertext ?? '').length + 200;
    if (current.length === MAX_CHANGES || (bytes + size > MAX_BYTES && current.length)) {
      out.push(current);
      current = [];
      bytes = 0;
    }
    current.push(item);
    bytes += size;
  }
  if (current.length) out.push(current);
  return out;
}
