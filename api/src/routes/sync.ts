import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { z } from 'zod';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';
import { burst } from '../lib/ratelimit';
import { requireSession } from '../lib/session';
import { base64Text, body, uuid } from '../lib/validate';

export const sync = new Hono<AppEnv>();
sync.use(requireSession);

export const RECORD_QUOTA = 50_000;
const MAX_BODY = 1_048_576;

const recordType = z.enum(['entry', 'entryPhoto', 'task', 'category', 'settings']);

const change = z.object({
  id: uuid,
  type: recordType,
  ciphertext: base64Text(700_000),
  nonce: base64Text(32),
  clientUpdatedAt: z.number().int().nonnegative().max(8.64e15),
  baseVersion: z.number().int().nonnegative().nullable(),
  deleted: z.boolean(),
});

const pushBody = z.object({ changes: z.array(change).min(1).max(200) });

interface RecordRow {
  id: string; type: string; version: number; ciphertext: string; nonce: string;
  client_updated_at: number; deleted: number;
}

const toWire = (row: RecordRow) => ({
  id: row.id, type: row.type, version: row.version, ciphertext: row.ciphertext, nonce: row.nonce,
  clientUpdatedAt: row.client_updated_at, deleted: row.deleted === 1,
});

/** Reads rows for a set of ids, ≤ 99 bound ids per query (D1 allows 100 parameters). */
async function readRows(db: D1Database, userId: string, ids: string[]): Promise<Map<string, RecordRow>> {
  const rows = new Map<string, RecordRow>();
  for (let i = 0; i < ids.length; i += 99) {
    const chunk = ids.slice(i, i + 99);
    const placeholders = chunk.map((_, index) => `?${index + 2}`).join(',');
    const result = await db.prepare(`SELECT id, type, version, ciphertext, nonce, client_updated_at, deleted FROM records WHERE user_id = ?1 AND id IN (${placeholders})`)
      .bind(userId, ...chunk).all<RecordRow>();
    for (const row of result.results) rows.set(row.id, row);
  }
  return rows;
}

/**
 * Push (SPEC §10.5). Every change gets a new per-user version. A change wins when the server
 * copy is still at its `baseVersion`, or — on a conflict — when it's newer by
 * `clientUpdatedAt` (last writer wins). A tombstone is final: nothing recreates it. The guards
 * run inside one D1 batch (a single transaction), so concurrent pushes can't interleave.
 * Losers come back in `conflicts` so the client can take the server copy.
 */
sync.post('/push', bodyLimit({ maxSize: MAX_BODY, onError: () => fail(413, 'too_large') }), async (c) => {
  const { userId, sessionId } = c.var.session;
  await burst(c.env, `sync:${userId}`);
  const { changes } = await body(c, pushBody);
  const ids = changes.map((change) => change.id);
  if (new Set(ids).size !== ids.length) fail(400, 'invalid_request');

  const before = await readRows(c.env.DB, userId, ids);
  const added = changes.filter((change) => !before.has(change.id)).length;
  const user = await c.env.DB.prepare('SELECT record_count FROM users WHERE id = ?1').bind(userId).first<{ record_count: number }>();
  if (!user) fail(401, 'unauthorized');
  if (user.record_count + added > RECORD_QUOTA) fail(413, 'quota_records');

  const statements: D1PreparedStatement[] = [];
  for (const change of changes) {
    statements.push(c.env.DB.prepare('UPDATE users SET next_version = next_version + 1 WHERE id = ?1').bind(userId));
    statements.push(c.env.DB.prepare(
      `INSERT INTO records (user_id, id, type, version, ciphertext, nonce, client_updated_at, deleted, size)
       VALUES (?1, ?2, ?3, (SELECT next_version FROM users WHERE id = ?1), ?4, ?5, ?6, ?7, ?8)
       ON CONFLICT (user_id, id) DO UPDATE SET
         type = excluded.type, version = excluded.version, ciphertext = excluded.ciphertext, nonce = excluded.nonce,
         client_updated_at = excluded.client_updated_at, deleted = excluded.deleted, size = excluded.size
       WHERE records.deleted = 0 AND (records.version = ?9 OR records.client_updated_at < excluded.client_updated_at)`,
    ).bind(userId, change.id, change.type, change.deleted ? '' : change.ciphertext, change.nonce, change.clientUpdatedAt,
      change.deleted ? 1 : 0, change.deleted ? 0 : change.ciphertext.length, change.baseVersion ?? -1));
  }
  // Incremental (a COUNT(*) would read every row of a big diary on each push); new ids only.
  if (added > 0) statements.push(c.env.DB.prepare('UPDATE users SET record_count = record_count + ?2 WHERE id = ?1').bind(userId, added));
  const results = await c.env.DB.batch(statements);
  const cursor = await c.env.DB.prepare('SELECT next_version FROM users WHERE id = ?1').bind(userId).first<{ next_version: number }>();

  // An upsert whose guard failed changed no row: that change lost.
  const accepted: { id: string; version: number }[] = [];
  const lostIds: string[] = [];
  changes.forEach((change, index) => {
    if ((results[index * 2 + 1]?.meta.changes ?? 0) > 0) accepted.push({ id: change.id, version: 0 });
    else lostIds.push(change.id);
  });
  const after = await readRows(c.env.DB, userId, ids);
  for (const item of accepted) item.version = after.get(item.id)?.version ?? 0;
  const conflicts = lostIds.map((id) => after.get(id)).filter((row): row is RecordRow => row !== undefined).map(toWire);

  if (accepted.length > 0 && cursor) {
    // Tell this user's other open devices to pull (SPEC §10.5 real-time).
    const hub = c.env.USER_HUB.get(c.env.USER_HUB.idFromName(userId));
    c.executionCtx.waitUntil(hub.notify(cursor.next_version, sessionId));
  }
  return c.json({ accepted, conflicts, cursor: cursor?.next_version ?? 0 });
});

const pullQuery = z.object({
  since: z.coerce.number().int().nonnegative().default(0),
  limit: z.coerce.number().int().min(1).max(500).default(500),
});

/** Pull: everything after the cursor, oldest first, in pages of up to 500. */
sync.get('/pull', async (c) => {
  const { userId } = c.var.session;
  await burst(c.env, `sync:${userId}`);
  const query = pullQuery.safeParse(c.req.query());
  if (!query.success) fail(400, 'invalid_request');
  const { since, limit } = query.data;
  const rows = await c.env.DB.prepare(
    `SELECT id, type, version, ciphertext, nonce, client_updated_at, deleted FROM records
     WHERE user_id = ?1 AND version > ?2 ORDER BY version LIMIT ?3`,
  ).bind(userId, since, limit + 1).all<RecordRow>();
  const page = rows.results.slice(0, limit);
  const next = page.at(-1)?.version ?? since;
  return c.json({ changes: page.map(toWire), cursor: next, hasMore: rows.results.length > limit });
});
