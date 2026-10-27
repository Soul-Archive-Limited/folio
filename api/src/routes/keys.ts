import { Hono } from 'hono';
import { z } from 'zod';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';
import { requireSession } from '../lib/session';
import { base64Text, body } from '../lib/validate';

/**
 * The recovery envelope: the data key wrapped with a key derived from the recovery key
 * (SPEC §10.3–10.4). Opaque to the server. Set once per account; replacing it needs a
 * freshly re-authenticated session.
 */
export const keys = new Hono<AppEnv>();
keys.use(requireSession);

keys.get('/recovery', async (c) => {
  const row = await c.env.DB.prepare(`SELECT envelope, created_at FROM key_envelopes WHERE user_id = ?1 AND kind = 'recovery'`)
    .bind(c.var.session.userId).first<{ envelope: string; created_at: number }>();
  if (!row) fail(404, 'not_found');
  return c.json({ envelope: row.envelope, createdAt: row.created_at });
});

const put = z.object({ envelope: base64Text(512), replace: z.boolean().optional() });

keys.put('/recovery', async (c) => {
  const { userId, reauthAt } = c.var.session;
  const input = await body(c, put);
  if (input.replace) {
    if (!reauthAt || Date.now() - reauthAt > 10 * 60_000) fail(403, 'reauth_required');
    await c.env.DB.prepare(`UPDATE key_envelopes SET envelope = ?2, created_at = ?3 WHERE user_id = ?1 AND kind = 'recovery'`)
      .bind(userId, input.envelope, Date.now()).run();
    return c.json({ ok: true });
  }
  const result = await c.env.DB.prepare(
    `INSERT INTO key_envelopes (user_id, kind, envelope, created_at) VALUES (?1, 'recovery', ?2, ?3) ON CONFLICT DO NOTHING`,
  ).bind(userId, input.envelope, Date.now()).run();
  if (result.meta.changes === 0) fail(409, 'exists');
  return c.json({ ok: true });
});
