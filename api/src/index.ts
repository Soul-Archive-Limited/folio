import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { HTTPException } from 'hono/http-exception';
import type { AppEnv } from './env';
import { fail, log } from './lib/errors';
import { account } from './routes/account';
import { auth } from './routes/auth';
import { blobs } from './routes/blobs';
import { keys } from './routes/keys';
import { link } from './routes/link';
import { live } from './routes/live';
import { sync } from './routes/sync';

export { UserHub } from './hub/UserHub';

const app = new Hono<AppEnv>().basePath('/api');

// Security headers on every response (SPEC §11.3, §13.8).
app.use(async (c, next) => {
  await next();
  if (c.res.status === 101) return;
  c.res.headers.set('x-content-type-options', 'nosniff');
  c.res.headers.set('referrer-policy', 'strict-origin-when-cross-origin');
  c.res.headers.set('strict-transport-security', 'max-age=63072000; includeSubDomains; preload');
  c.res.headers.set('x-frame-options', 'DENY');
  if (!c.res.headers.has('cache-control')) c.res.headers.set('cache-control', 'no-store');
});

// CSRF (SPEC §10.2): state-changing requests that come with an Origin must come from the
// app's own origin, and a cookie-authenticated one must carry an Origin at all. Bearer
// requests (iOS) carry no ambient credentials. Apple's form_post callback is cross-site by
// design and bound by its state cookie instead.
app.use(async (c, next) => {
  const method = c.req.method;
  if (method === 'GET' || method === 'HEAD' || method === 'OPTIONS' || c.req.path === '/api/auth/callback/apple') return next();
  const origin = c.req.header('origin');
  const usesCookie = !c.req.header('authorization') && (c.req.header('cookie') ?? '').includes('__Host-folio_session=');
  if (origin && origin !== c.env.APP_ORIGIN) fail(403, 'bad_origin');
  if (usesCookie && !origin) fail(403, 'bad_origin');
  await next();
});

// Body size limits on everything (SPEC §13.7): 1 MB for a sync push, 64 KB elsewhere. Blob
// uploads stream with a checked Content-Length instead (≤ 4 MB).
const smallBody = bodyLimit({ maxSize: 64 * 1024, onError: () => fail(413, 'too_large') });
app.use(async (c, next) => {
  if (c.req.path.startsWith('/api/blobs/') || c.req.path === '/api/sync/push') return next();
  return smallBody(c, next);
});

app.route('/auth', auth);
app.route('/sync', sync);
app.route('/blobs', blobs);
app.route('/keys', keys);
app.route('/link', link);
app.route('/live', live);
app.route('/account', account);
app.get('/health', (c) => c.json({ ok: true }));

app.notFound(() => fail(404, 'not_found'));

app.onError((error, c) => {
  if (error instanceof HTTPException) return error.getResponse();
  log('error', 'unhandled', { path: c.req.path, name: error.name });
  return c.json({ error: 'server_error' }, 500);
});

/** Nightly: drop expired codes, OAuth states, handoffs, link requests, sessions and old counters. */
export async function cleanUp(env: AppEnv['Bindings'], now = Date.now()): Promise<void> {
  const db = env.DB;
  await db.batch([
    db.prepare('DELETE FROM verification_codes WHERE expires_at < ?1').bind(now),
    db.prepare('DELETE FROM oauth_states WHERE expires_at < ?1').bind(now),
    db.prepare('DELETE FROM handoff_codes WHERE expires_at < ?1').bind(now),
    db.prepare('DELETE FROM link_requests WHERE expires_at < ?1').bind(now),
    db.prepare('DELETE FROM sessions WHERE expires_at < ?1').bind(now),
    db.prepare('DELETE FROM rate_limits WHERE window_start < ?1').bind(Math.floor(now / 1000) - 2 * 86_400),
  ]);
}

export default {
  fetch: app.fetch,
  async scheduled(_controller: ScheduledController, env: AppEnv['Bindings'], ctx: ExecutionContext) {
    ctx.waitUntil(cleanUp(env));
  },
} satisfies ExportedHandler<AppEnv['Bindings']>;
