/**
 * Photos on the web (SPEC §5, §10.3): the same three renditions the iPhone makes — full ≤ 2048 px,
 * display ≤ 1080 px, thumbnail ≤ 240 px — re-encoded from pixels (so no EXIF or GPS survives),
 * sealed with the Data Key and sent in one request (DECISIONS 190). Downloads are decrypted
 * into object URLs that live only as long as the tab.
 */
import { api } from './api.ts';
import { openBlob, sealBlob, type DataKey } from './crypto.ts';

export type Rendition = 'thumb' | 'display' | 'full';
const AAD_TYPE = { thumb: 'thumb', display: 'display', full: 'photo' } as const;
const SIZES = { full: [2048, 0.82], display: [1080, 0.72], thumb: [240, 0.7] } as const;
export const MAX_PHOTOS = 10;

export interface PreparedPhoto {
  thumb: Uint8Array;
  display: Uint8Array;
  full: Uint8Array;
  width: number;
  height: number;
  previewURL: string;
}

export class UnsupportedPhoto extends Error {}

async function encode(bitmap: ImageBitmap, maxEdge: number, quality: number): Promise<{ bytes: Uint8Array; width: number; height: number }> {
  const scale = Math.min(1, maxEdge / Math.max(bitmap.width, bitmap.height));
  const width = Math.max(1, Math.round(bitmap.width * scale));
  const height = Math.max(1, Math.round(bitmap.height * scale));
  const canvas = new OffscreenCanvas(width, height);
  const context = canvas.getContext('2d')!;
  context.imageSmoothingQuality = 'high';
  context.drawImage(bitmap, 0, 0, width, height);
  const blob = await canvas.convertToBlob({ type: 'image/jpeg', quality });
  return { bytes: new Uint8Array(await blob.arrayBuffer()), width, height };
}

/** Decodes a picked file (orientation applied) and makes the three JPEG renditions. */
export async function preparePhoto(file: File): Promise<PreparedPhoto> {
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
  } catch {
    throw new UnsupportedPhoto(file.name);
  }
  try {
    const full = await encode(bitmap, ...SIZES.full);
    const display = await encode(bitmap, ...SIZES.display);
    const thumb = await encode(bitmap, ...SIZES.thumb);
    const previewURL = URL.createObjectURL(new Blob([display.bytes as BlobPart], { type: 'image/jpeg' }));
    return { full: full.bytes, display: display.bytes, thumb: thumb.bytes, width: full.width, height: full.height, previewURL };
  } finally {
    bitmap.close();
  }
}

/** Seals all three and uploads them in one request (`PUT /api/blobs/photo/:id`). */
export async function uploadPhoto(key: DataKey, userId: string, photoId: string, photo: PreparedPhoto) {
  const parts = await Promise.all((['thumb', 'display', 'full'] as const).map((r) => sealBlob(key, photo[r], photoId, AAD_TYPE[r], userId)));
  const body = new Uint8Array(12 + parts.reduce((n, p) => n + p.length, 0));
  const view = new DataView(body.buffer);
  let offset = 12;
  parts.forEach((part, i) => {
    view.setUint32(i * 4, part.length);
    body.set(part, offset);
    offset += part.length;
  });
  await api('PUT', `blobs/photo/${photoId.toLowerCase()}`, body, { headers: { 'content-type': 'application/octet-stream' } });
  cache.set(`${photoId.toLowerCase()}.thumb`, Promise.resolve(URL.createObjectURL(new Blob([photo.thumb as BlobPart], { type: 'image/jpeg' }))));
  cache.set(`${photoId.toLowerCase()}.display`, Promise.resolve(photo.previewURL));
}

export async function deletePhotoBlobs(photoId: string) {
  await Promise.allSettled((['thumb', 'display', 'full'] as const).map((r) => api('DELETE', `blobs/${photoId.toLowerCase()}.${r}`)));
  for (const r of ['thumb', 'display', 'full']) {
    const url = cache.get(`${photoId.toLowerCase()}.${r}`);
    cache.delete(`${photoId.toLowerCase()}.${r}`);
    url?.then((u) => u && URL.revokeObjectURL(u));
  }
}

const cache = new Map<string, Promise<string | null>>();
let active = 0;
const queue: (() => void)[] = [];
const slot = () => new Promise<void>((resolve) => (active < 4 ? (active++, resolve()) : queue.push(() => (active++, resolve()))));
const release = () => { active--; queue.shift()?.(); };

/** A decrypted rendition as an object URL (cached for the tab); null if it can't be had. */
export function photoURL(key: DataKey, userId: string, photoId: string, rendition: Rendition): Promise<string | null> {
  const id = `${photoId.toLowerCase()}.${rendition}`;
  let entry = cache.get(id);
  if (!entry) {
    entry = (async () => {
      await slot();
      try {
        const sealed = await api<Uint8Array>('GET', `blobs/${id}`);
        const plain = await openBlob(key, sealed, photoId, AAD_TYPE[rendition], userId);
        return URL.createObjectURL(new Blob([plain as BlobPart], { type: sniff(plain) }));
      } catch {
        cache.delete(id);
        return null;
      } finally {
        release();
      }
    })();
    cache.set(id, entry);
  }
  return entry;
}

/** A rendition's decrypted bytes (Duplicate re-uploads them under a new id). */
export async function photoBytes(key: DataKey, userId: string, photoId: string, rendition: Rendition): Promise<Uint8Array | null> {
  try {
    const sealed = await api<Uint8Array>('GET', `blobs/${photoId.toLowerCase()}.${rendition}`);
    return await openBlob(key, sealed, photoId, AAD_TYPE[rendition], userId);
  } catch {
    return null;
  }
}

/** JPEG from the web and new iPhone builds; HEIC from photos synced by build 43 (DECISIONS 193). */
function sniff(bytes: Uint8Array): string {
  if (bytes[0] === 0xff && bytes[1] === 0xd8) return 'image/jpeg';
  if (String.fromCharCode(...bytes.subarray(4, 8)) === 'ftyp') return 'image/heic';
  if (bytes[0] === 0x89 && bytes[1] === 0x50) return 'image/png';
  return 'application/octet-stream';
}

/** Forget every decrypted photo (sign out, lock). */
export function clearPhotoCache() {
  for (const url of cache.values()) url.then((u) => u && URL.revokeObjectURL(u));
  cache.clear();
}
