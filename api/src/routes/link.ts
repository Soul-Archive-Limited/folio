import { Hono } from 'hono';
import { z } from 'zod';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';
import { limit } from '../lib/ratelimit';
import { requireSession } from '../lib/session';
import { base64Text, body, uuid } from '../lib/validate';

/**
 * Linking a browser or device with a QR (SPEC §10.4). The new device (signed in, no data
 * key yet) registers an X25519 public key; a signed-in device of the same account approves
 * by sending the data key encrypted to it. The server only relays and forgets after 5 min.
 */
export const link = new Hono<AppEnv>();
link.use(requireSession);

const TTL = 5 * 60_000;
const x25519Key = base64Text(64).refine((value) => value.replace(/=+$/, '').length === 43, 'x25519');

interface LinkRow {
  id: string; user_id: string; session_id: string; public_key: string; device_name: string; platform: string;
  sender_public_key: string | null; envelope: string | null; envelope_nonce: string | null; expires_at: number;
}

link.post('/', async (c) => {
  const { userId, sessionId, platform } = c.var.session;
  await limit(c.env, `link:${userId}`, 10, 3600);
  const input = await body(c, z.object({ publicKey: x25519Key }));
  const session = await c.env.DB.prepare('SELECT device_name FROM sessions WHERE id = ?1').bind(sessionId).first<{ device_name: string }>();
  const id = crypto.randomUUID();
  const now = Date.now();
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM link_requests WHERE user_id = ?1 AND expires_at < ?2').bind(userId, now),
    c.env.DB.prepare(
      `INSERT INTO link_requests (id, user_id, session_id, public_key, device_name, platform, created_at, expires_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`,
    ).bind(id, userId, sessionId, input.publicKey, session?.device_name ?? 'Device', platform, now, now + TTL),
  ]);
  return c.json({ id, expiresAt: now + TTL });
});

async function load(c: { env: AppEnv['Bindings'] }, id: string, userId: string): Promise<LinkRow> {
  if (!uuid.safeParse(id).success) fail(404, 'not_found');
  // Scoped by user: another account's request id is simply "not found".
  const row = await c.env.DB.prepare('SELECT * FROM link_requests WHERE id = ?1 AND user_id = ?2').bind(id, userId).first<LinkRow>();
  if (!row) fail(404, 'not_found');
  if (row.expires_at < Date.now()) {
    await c.env.DB.prepare('DELETE FROM link_requests WHERE id = ?1').bind(id).run();
    fail(410, 'expired');
  }
  return row;
}

/** The approving device reads who's asking; the requester polls for the envelope. */
link.get('/:id', async (c) => {
  const { userId, sessionId } = c.var.session;
  const row = await load(c, c.req.param('id'), userId);
  if (row.session_id !== sessionId) {
    return c.json({ id: row.id, publicKey: row.public_key, deviceName: row.device_name, platform: row.platform, expiresAt: row.expires_at });
  }
  if (!row.envelope) return c.json({ status: 'waiting', expiresAt: row.expires_at });
  // Delivered once, then forgotten.
  await c.env.DB.prepare('DELETE FROM link_requests WHERE id = ?1').bind(row.id).run();
  return c.json({ status: 'approved', senderPublicKey: row.sender_public_key, envelope: row.envelope, nonce: row.envelope_nonce });
});

const approve = z.object({ senderPublicKey: x25519Key, envelope: base64Text(512), nonce: base64Text(32) });

link.post('/:id/approve', async (c) => {
  const { userId, sessionId } = c.var.session;
  const row = await load(c, c.req.param('id'), userId);
  if (row.session_id === sessionId) fail(403, 'forbidden');   // a device can't approve itself
  if (row.envelope) fail(409, 'already_approved');
  const input = await body(c, approve);
  await c.env.DB.prepare('UPDATE link_requests SET sender_public_key = ?2, envelope = ?3, envelope_nonce = ?4 WHERE id = ?1 AND envelope IS NULL')
    .bind(row.id, input.senderPublicKey, input.envelope, input.nonce).run();
  const hub = c.env.USER_HUB.get(c.env.USER_HUB.idFromName(userId));
  c.executionCtx.waitUntil(hub.notifyLink(row.id));
  return c.json({ ok: true });
});

link.delete('/:id', async (c) => {
  await c.env.DB.prepare('DELETE FROM link_requests WHERE id = ?1 AND user_id = ?2').bind(c.req.param('id'), c.var.session.userId).run();
  return c.json({ ok: true });
});
