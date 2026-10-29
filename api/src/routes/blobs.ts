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
