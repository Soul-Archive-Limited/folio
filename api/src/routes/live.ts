import { Hono } from 'hono';
import type { AppEnv } from '../env';
import { fail } from '../lib/errors';
import { requireSession } from '../lib/session';

/** GET /api/live: one WebSocket per foreground app or visible tab, to the user's UserHub. */
export const live = new Hono<AppEnv>();

live.get('/', requireSession, async (c) => {
  if (c.req.header('upgrade')?.toLowerCase() !== 'websocket') fail(426, 'upgrade_required');
  // Cross-site WebSocket hijacking: a browser socket must come from the app's own origin.
  const origin = c.req.header('origin');
  if (origin && origin !== c.env.APP_ORIGIN) fail(403, 'bad_origin');
  const { userId, sessionId } = c.var.session;
  // The socket opens with the current cursor, so a foreground visit with nothing new costs
  // one request instead of a socket plus a pull (SPEC §10.5 budget).
  const user = await c.env.DB.prepare('SELECT next_version FROM users WHERE id = ?1').bind(userId).first<{ next_version: number }>();
  const headers = new Headers(c.req.raw.headers);
  headers.set('x-folio-session', sessionId);
  headers.set('x-folio-cursor', String(user?.next_version ?? 0));
  headers.delete('authorization');
  headers.delete('cookie');
  const hub = c.env.USER_HUB.get(c.env.USER_HUB.idFromName(userId));
  return hub.fetch(new Request(c.req.raw.url, { headers }));
});
