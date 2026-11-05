import { Hono } from 'hono';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';
import { INVITE_TTL, inviteHash, isOwner, MAX_OPEN_INVITES, newInviteCode, normaliseInvite } from '../lib/invites';
import { limit } from '../lib/ratelimit';
import { requireSession } from '../lib/session';

/** The owner's invites (Batch J): make one (the code is shown once), list them, revoke unused ones. */
export const invites = new Hono<AppEnv>();
invites.use(requireSession);
invites.use(async (c, next) => {
  if (!(await isOwner(c.env, c.var.session.userId))) fail(403, 'forbidden');
  await next();
});

type Row = { id: string; hint: string; created_at: number; expires_at: number; used_at: number | null; revoked_at: number | null };

function status(row: Row, now: number) {
  if (row.used_at) return 'used';
  if (row.revoked_at) return 'revoked';
  return row.expires_at <= now ? 'expired' : 'open';
}

invites.get('/', async (c) => {
  const now = Date.now();
  const rows = await c.env.DB.prepare(
    'SELECT id, hint, created_at, expires_at, used_at, revoked_at FROM invites WHERE created_by = ?1 ORDER BY created_at DESC LIMIT 50',
  ).bind(c.var.session.userId).all<Row>();
  return c.json({
    invites: rows.results.map((r) => ({ id: r.id, hint: r.hint, createdAt: r.created_at, expiresAt: r.expires_at, usedAt: r.used_at, status: status(r, now) })),
  });
});

invites.post('/', async (c) => {
  const userId = c.var.session.userId;
  await limit(c.env, `invite-create:${userId}`, 30, 24 * 3600);
  const now = Date.now();
  const open = await c.env.DB.prepare(
    'SELECT COUNT(*) AS n FROM invites WHERE created_by = ?1 AND used_at IS NULL AND revoked_at IS NULL AND expires_at > ?2',
  ).bind(userId, now).first<{ n: number }>();
  if ((open?.n ?? 0) >= MAX_OPEN_INVITES) fail(409, 'too_many_invites');
  const code = newInviteCode();
  const id = crypto.randomUUID();
  await c.env.DB.prepare('INSERT INTO invites (id, code_hash, hint, created_by, created_at, expires_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)')
    .bind(id, await inviteHash(c.env, normaliseInvite(code)!), code.slice(-2), userId, now, now + INVITE_TTL).run();
  return c.json({ id, code, expiresAt: now + INVITE_TTL });
});

invites.delete('/:id', async (c) => {
  const row = await c.env.DB.prepare(
    'UPDATE invites SET revoked_at = ?3 WHERE id = ?1 AND created_by = ?2 AND used_at IS NULL AND revoked_at IS NULL RETURNING id',
  ).bind(c.req.param('id'), c.var.session.userId, Date.now()).first();
  if (!row) fail(404, 'not_found');
  return c.json({ ok: true });
});
