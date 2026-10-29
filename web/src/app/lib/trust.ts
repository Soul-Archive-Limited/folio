/**
 * "Trust this browser for 30 days" (SPEC §10.3): the Data Key is sealed with a device key that
 * is a non-extractable CryptoKey, and both are kept in IndexedDB. Script on this origin can
 * use the device key but never read it, and nothing leaves the browser. Signing out, locking
 * or 30 days later removes it.
 */
import { aesOpen, aesSeal, importDataKey, type DataKey } from './crypto.ts';
import { utf8 } from './bytes.ts';

const DB = 'folio';
const STORE = 'trust';
const DAYS_30 = 30 * 86_400_000;

interface Trusted { userId: string; deviceKey: CryptoKey; nonce: Uint8Array; sealed: Uint8Array; expiresAt: number }

function open(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function tx<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const db = await open();
  try {
    return await new Promise<T>((resolve, reject) => {
      const request = run(db.transaction(STORE, mode).objectStore(STORE));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  } finally {
    db.close();
  }
}

const aad = (userId: string) => utf8.encode(`folio/web-trust/v1|${userId.toLowerCase()}`);

/** Remembers the raw Data Key for 30 days, sealed with a fresh non-extractable device key. */
export async function trustBrowser(userId: string, rawDataKey: Uint8Array) {
  const deviceKey = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
  const { nonce, ciphertextAndTag } = await aesSeal(deviceKey, rawDataKey, aad(userId));
  const record: Trusted = { userId: userId.toLowerCase(), deviceKey, nonce, sealed: ciphertextAndTag, expiresAt: Date.now() + DAYS_30 };
  await tx('readwrite', (s) => s.put(record, 'key'));
}

/** The trusted Data Key for this user, if there is one and it hasn't expired. */
export async function trustedKey(userId: string): Promise<DataKey | null> {
  try {
    const record = await tx<Trusted | undefined>('readonly', (s) => s.get('key'));
    if (!record || record.userId !== userId.toLowerCase() || record.expiresAt < Date.now()) {
      if (record) await forgetBrowser();
      return null;
    }
    return importDataKey(await aesOpen(record.deviceKey, record.nonce, record.sealed, aad(userId)));
  } catch {
    return null;
  }
}

export async function isTrusted(): Promise<{ expiresAt: number } | null> {
  try {
    const record = await tx<Trusted | undefined>('readonly', (s) => s.get('key'));
    return record ? { expiresAt: record.expiresAt } : null;
  } catch {
    return null;
  }
}

export async function forgetBrowser() {
  try { await tx('readwrite', (s) => s.delete('key')); } catch { /* storage blocked */ }
}
