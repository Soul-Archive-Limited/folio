import { Hono } from 'hono';
import { z } from 'zod';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';
import { limit } from '../lib/ratelimit';
import { clearSessionCookie, requireSession } from '../lib/session';
import { body, uuid } from '../lib/validate';

export const account = new Hono<AppEnv>();
account.use(requireSession);

/** Who's signed in, which sign-in methods are linked, and whether a recovery key exists. */
account.get('/me', async (c) => {
  const { userId, sessionId, platform } = c.var.session;
  const [user, providers, recovery] = await c.env.DB.batch([
    c.env.DB.prepare('SELECT email, created_at, record_count, blob_bytes FROM users WHERE id = ?1').bind(userId),
    c.env.DB.prepare('SELECT provider FROM accounts WHERE user_id = ?1 ORDER BY created_at').bind(userId),
    c.env.DB.prepare(`SELECT 1 AS present FROM key_envelopes WHERE user_id = ?1 AND kind = 'recovery'`).bind(userId),
  ]);
  const row = user?.results[0] as { email: string | null; created_at: number; record_count: number; blob_bytes: number } | undefined;
  if (!row) fail(401, 'unauthorized');
  return c.json({
    userId, sessionId, platform, email: row.email, createdAt: row.created_at,
    providers: (providers?.results ?? []).map((p) => (p as { provider: string }).provider),
    hasRecoveryKey: (recovery?.results.length ?? 0) > 0,
    usage: { records: row.record_count, photoBytes: row.blob_bytes },
  });
});

/** Devices = sessions (SPEC §6.9): name, platform, last seen, and which one is this. */
account.get('/devices', async (c) => {
  const { userId, sessionId } = c.var.session;
  const rows = await c.env.DB.prepare(
    'SELECT id, device_name, platform, created_at, last_seen_at FROM sessions WHERE user_id = ?1 AND expires_at > ?2 ORDER BY last_seen_at DESC',
  ).bind(userId, Date.now()).all<{ id: string; device_name: string; platform: string; created_at: number; last_seen_at: number }>();
  return c.json({
    devices: rows.results.map((r) => ({
      id: r.id, name: r.device_name, platform: r.platform, createdAt: r.created_at, lastSeenAt: r.last_seen_at, current: r.id === sessionId,
    })),
  });
});

account.delete('/devices/:id', async (c) => {
  const id = c.req.param('id');
  if (!uuid.safeParse(id).success) fail(404, 'not_found');
  const result = await c.env.DB.prepare('DELETE FROM sessions WHERE id = ?1 AND user_id = ?2').bind(id, c.var.session.userId).run();
  if (result.meta.changes === 0) fail(404, 'not_found');
  const hub = c.env.USER_HUB.get(c.env.USER_HUB.idFromName(c.var.session.userId));
  c.executionCtx.waitUntil(hub.disconnect(id));
  if (id === c.var.session.sessionId) clearSessionCookie(c);
  return c.json({ ok: true });
});

account.post('/devices/sign-out-others', async (c) => {
  const { userId, sessionId } = c.var.session;
  const removed = await c.env.DB.prepare('DELETE FROM sessions WHERE user_id = ?1 AND id != ?2 RETURNING id').bind(userId, sessionId).all<{ id: string }>();
  const hub = c.env.USER_HUB.get(c.env.USER_HUB.idFromName(userId));
  c.executionCtx.waitUntil(Promise.all(removed.results.map((r) => hub.disconnect(r.id))));
  return c.json({ ok: true, signedOut: removed.results.length });
});

/**
 * Delete account (SPEC §10.6, App Store 5.1.1(v)). Needs a sign-in on this session within the
 * last 10 minutes and the word DELETE. The user is marked as deleting at once (every session
 * stops working), then UserHub wipes R2, D1 rows, revokes Apple tokens, sends the
 * confirmation and logs only a keyed hash of the id.
 */
account.post('/delete', async (c) => {
  const { userId, reauthAt } = c.var.session;
  await limit(c.env, `delete:${userId}`, 3, 86_400);
  const input = await body(c, z.object({ confirm: z.literal('DELETE') }));
  void input;
  if (!reauthAt || Date.now() - reauthAt > 10 * 60_000) fail(403, 'reauth_required');
  const user = await c.env.DB.prepare('UPDATE users SET deleting = 1 WHERE id = ?1 AND deleting = 0 RETURNING email').bind(userId).first<{ email: string | null }>();
  if (!user) fail(409, 'already_deleting');
  const hub = c.env.USER_HUB.get(c.env.USER_HUB.idFromName(userId));
  await hub.startWipe(userId, user.email);
  clearSessionCookie(c);
  return c.json({ ok: true });
});
