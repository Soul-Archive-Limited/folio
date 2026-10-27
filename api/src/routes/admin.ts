import { Hono } from 'hono';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';

/**
 * GET /api/admin/usage — totals only, no user content (SPEC §15.2). Cloudflare Access sits
 * in front of /api/admin; the Worker also verifies Access's signed JWT, so the route is
 * closed even if the Access policy were removed.
 */
export const admin = new Hono<AppEnv>();
const keySets = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

admin.use(async (c, next) => {
  const team = c.env.ACCESS_TEAM_DOMAIN;
  const token = c.req.header('cf-access-jwt-assertion');
  if (!team || !c.env.ACCESS_AUD || !token) fail(403, 'forbidden');
  let keys = keySets.get(team);
  if (!keys) {
    keys = createRemoteJWKSet(new URL(`https://${team}/cdn-cgi/access/certs`));
    keySets.set(team, keys);
  }
  try {
    await jwtVerify(token, keys, { issuer: `https://${team}`, audience: c.env.ACCESS_AUD, algorithms: ['RS256'] });
  } catch {
    fail(403, 'forbidden');
  }
  await next();
});

admin.get('/usage', async (c) => {
  const day = Date.now() - 86_400_000;
  const [users, active, records, photos, deletions] = await c.env.DB.batch([
    c.env.DB.prepare('SELECT COUNT(*) AS n FROM users'),
    c.env.DB.prepare('SELECT COUNT(DISTINCT user_id) AS n FROM sessions WHERE last_seen_at > ?1').bind(day),
    c.env.DB.prepare('SELECT COALESCE(SUM(record_count), 0) AS n FROM users'),
    c.env.DB.prepare('SELECT COALESCE(SUM(blob_bytes), 0) AS n FROM users'),
    c.env.DB.prepare('SELECT COUNT(*) AS n FROM deletions_log WHERE deleted_at > ?1').bind(Date.now() - 30 * 86_400_000),
  ]);
  const n = (r: D1Result | undefined) => (r?.results[0] as { n: number } | undefined)?.n ?? 0;
  return c.json({
    users: n(users), activeUsers24h: n(active), records: n(records), photoBytes: n(photos),
    deletions30d: n(deletions), databaseBytes: users?.meta.size_after ?? null,
  });
});
