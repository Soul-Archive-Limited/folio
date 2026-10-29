import { Hono } from 'hono';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';
import { limit } from '../lib/ratelimit';
import { requireSession } from '../lib/session';

export const blobs = new Hono<AppEnv>();
blobs.use(requireSession);

export const BLOB_MAX = 4 * 1024 * 1024;
export const BLOB_QUOTA = 1024 * 1024 * 1024;

/** `<photo UUID>.<rendition>`; the server never learns more than that it's a photo. */
const BLOB_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(thumb|display|full)$/;

const key = (userId: string, blobId: string) => `u/${userId}/${blobId}`;

const RENDITIONS = ['thumb', 'display', 'full'] as const;
const PHOTO_HEADER = 12;
/** One photo per request (Batch F): 600 an hour and 3,000 a day per user (DECISIONS 190). */
export const PHOTO_PUTS_PER_HOUR = 600;
export const PHOTO_PUTS_PER_DAY = 3000;

function blobId(raw: string): string {
  const id = raw.toLowerCase();
  if (!BLOB_ID.test(id)) fail(400, 'invalid_request');
  return id;
}

/** PUT: streamed straight to R2 with a fixed length (≤ 4 MB), counted against 1 GB. */
blobs.put('/:id', async (c) => {
  const { userId } = c.var.session;
  const id = blobId(c.req.param('id'));
  // 60 photos an hour, each three renditions (DECISIONS 186).
  await limit(c.env, `blob-put:${userId}`, 180, 3600);
  const length = Number(c.req.header('content-length'));
  if (!Number.isInteger(length) || length <= 0) fail(411, 'length_required');
  if (length > BLOB_MAX) fail(413, 'too_large');
  if (!c.req.raw.body) fail(400, 'invalid_request');

  const existing = await c.env.DB.prepare('SELECT size FROM blobs WHERE user_id = ?1 AND id = ?2').bind(userId, id).first<{ size: number }>();
  const user = await c.env.DB.prepare('SELECT blob_bytes FROM users WHERE id = ?1').bind(userId).first<{ blob_bytes: number }>();
  if (!user) fail(401, 'unauthorized');
  if (user.blob_bytes - (existing?.size ?? 0) + length > BLOB_QUOTA) fail(413, 'quota_photos');

  // FixedLengthStream makes R2 reject a body that doesn't match the declared length.
  const { readable, writable } = new FixedLengthStream(length);
  const pumped = c.req.raw.body.pipeTo(writable);
  await c.env.BLOBS.put(key(userId, id), readable, { httpMetadata: { contentType: 'application/octet-stream' } });
  await pumped;
  const now = Date.now();
  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO blobs (user_id, id, size, created_at) VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT (user_id, id) DO UPDATE SET size = excluded.size, created_at = excluded.created_at`,
    ).bind(userId, id, length, now),
    c.env.DB.prepare('UPDATE users SET blob_bytes = (SELECT COALESCE(SUM(size), 0) FROM blobs WHERE user_id = ?1) WHERE id = ?1').bind(userId),
  ]);
  return c.json({ id, size: length });
});

/**
 * PUT /photo/:photoId — a photo's three sealed renditions in one request, so a first sync of
 * a big diary isn't throttled per rendition (Batch F, DECISIONS 190). Body: three big-endian
 * uint32 lengths (thumb, display, full), then the three blobs in that order. Stored as the
 * same three R2 objects the single PUT writes, so downloads don't change.
 */
blobs.put('/photo/:photoId', async (c) => {
  const { userId } = c.var.session;
  const photoId = c.req.param('photoId').toLowerCase();
  if (!BLOB_ID.test(`${photoId}.full`)) fail(400, 'invalid_request');
  await limit(c.env, `photo-put:${userId}`, PHOTO_PUTS_PER_HOUR, 3600);
  await limit(c.env, `photo-put-day:${userId}`, PHOTO_PUTS_PER_DAY, 86_400);
  const length = Number(c.req.header('content-length'));
  if (!Number.isInteger(length) || length <= PHOTO_HEADER) fail(411, 'length_required');
  if (length > PHOTO_HEADER + 3 * BLOB_MAX) fail(413, 'too_large');

  const bytes = new Uint8Array(await c.req.arrayBuffer());
  if (bytes.byteLength !== length) fail(400, 'invalid_request');
  const view = new DataView(bytes.buffer, bytes.byteOffset, PHOTO_HEADER);
  const sizes = [view.getUint32(0), view.getUint32(4), view.getUint32(8)];
  if (sizes.some((n) => n === 0 || n > BLOB_MAX) || sizes.reduce((a, b) => a + b, PHOTO_HEADER) !== length) fail(400, 'invalid_request');
  const ids = RENDITIONS.map((r) => `${photoId}.${r}`) as [string, string, string];

  const existing = await c.env.DB.prepare('SELECT COALESCE(SUM(size), 0) AS size FROM blobs WHERE user_id = ?1 AND id IN (?2, ?3, ?4)')
    .bind(userId, ...ids).first<{ size: number }>();
  const user = await c.env.DB.prepare('SELECT blob_bytes FROM users WHERE id = ?1').bind(userId).first<{ blob_bytes: number }>();
  if (!user) fail(401, 'unauthorized');
  if (user.blob_bytes - (existing?.size ?? 0) + length - PHOTO_HEADER > BLOB_QUOTA) fail(413, 'quota_photos');

  let offset = PHOTO_HEADER;
  const parts = sizes.map((size) => {
    const part = bytes.subarray(offset, offset + size);
    offset += size;
    return part;
  });
  await Promise.all(parts.map((part, i) => c.env.BLOBS.put(key(userId, ids[i]!), part, { httpMetadata: { contentType: 'application/octet-stream' } })));
  const now = Date.now();
  await c.env.DB.batch([
    ...parts.map((part, i) => c.env.DB.prepare(
      `INSERT INTO blobs (user_id, id, size, created_at) VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT (user_id, id) DO UPDATE SET size = excluded.size, created_at = excluded.created_at`,
    ).bind(userId, ids[i]!, part.byteLength, now)),
    c.env.DB.prepare('UPDATE users SET blob_bytes = (SELECT COALESCE(SUM(size), 0) FROM blobs WHERE user_id = ?1) WHERE id = ?1').bind(userId),
  ]);
  return c.json({ id: photoId, size: length - PHOTO_HEADER });
});

/** GET: streamed; encrypted and immutable, so it can be cached privately for a year. */
blobs.get('/:id', async (c) => {
  const { userId } = c.var.session;
  const id = blobId(c.req.param('id'));
  const object = await c.env.BLOBS.get(key(userId, id));
  if (!object) fail(404, 'not_found');
  return new Response(object.body, {
    headers: {
      'content-type': 'application/octet-stream',
      'content-disposition': 'attachment',
      'content-length': String(object.size),
      'cache-control': 'private, max-age=31536000, immutable',
      etag: object.httpEtag,
    },
  });
});

/** DELETE: a permanently deleted photo's renditions (SPEC §10.5 purge). */
blobs.delete('/:id', async (c) => {
  const { userId } = c.var.session;
  const id = blobId(c.req.param('id'));
  await c.env.BLOBS.delete(key(userId, id));
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM blobs WHERE user_id = ?1 AND id = ?2').bind(userId, id),
    c.env.DB.prepare('UPDATE users SET blob_bytes = (SELECT COALESCE(SUM(size), 0) FROM blobs WHERE user_id = ?1) WHERE id = ?1').bind(userId),
  ]);
  return c.json({ ok: true });
});
