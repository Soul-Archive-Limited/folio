import { Hono, type Context } from 'hono';
import { getCookie, setCookie, deleteCookie } from 'hono/cookie';
import { z } from 'zod';
import type { AppEnv } from '../env';
import { appleAuthorizeURL, exchangeAppleCode, verifyAppleIdToken } from '../auth/apple';
import { applyAppleEvent, verifyAppleNotification } from '../auth/apple-notifications';
import { exchangeGoogleCode, googleAuthorizeURL, verifyGoogleIdToken } from '../auth/google';
import { verifyTurnstile } from '../auth/turnstile';
import { checkInvite, normaliseEmail, resolveUser } from '../auth/users';
import { HTTPException } from 'hono/http-exception';
import { presentedInviteHash } from '../lib/invites';
import { hmacHex, randomToken, sealToken, sha256Base64url, sha256Hex, sixDigitCode, timingSafeEqual } from '../lib/crypto';
import { emailSender, signInCodeEmail } from '../lib/email';
import { fail, log } from '../lib/errors';
import { clientIP, ipKey, limit } from '../lib/ratelimit';
import { clearSessionCookie, createSession, lookupSession, presentedToken, requireSession, setSessionCookie } from '../lib/session';
import { body, deviceName } from '../lib/validate';

export const auth = new Hono<AppEnv>();

const CODE_TTL = 10 * 60_000;
const CODE_ATTEMPTS = 5;
const OAUTH_TTL = 10 * 60_000;
const HANDOFF_TTL = 60_000;
const OAUTH_COOKIE = 'folio_oauth';

// MARK: Finishing a sign-in

/**
 * Creates the session, or — for `reauth` — marks the caller's current session as freshly
 * re-authenticated (delete account, SPEC §10.6) when it belongs to the same user.
 */
async function finish(c: Context<AppEnv>, userId: string, isNew: boolean, platform: 'ios' | 'web', device: string, reauth: boolean) {
  if (reauth) {
    const presented = presentedToken(c);
    const current = presented ? await lookupSession(c.env, presented.token) : null;
    if (!current || current.userId !== userId) fail(403, 'reauth_mismatch');
    await c.env.DB.prepare('UPDATE sessions SET reauth_at = ?2 WHERE id = ?1').bind(current.sessionId, Date.now()).run();
    return c.json({ reauthenticated: true });
  }
  const session = await createSession(c.env, userId, platform, device);
  const hasRecoveryKey = await recoveryKeyExists(c, userId);
  if (platform === 'web') {
    setSessionCookie(c, session.token);
    return c.json({ userId, isNew, hasRecoveryKey });
  }
  return c.json({ token: session.token, sessionId: session.sessionId, expiresAt: session.expiresAt, userId, isNew, hasRecoveryKey });
}

async function recoveryKeyExists(c: Context<AppEnv>, userId: string): Promise<boolean> {
  const row = await c.env.DB.prepare(`SELECT 1 AS present FROM key_envelopes WHERE user_id = ?1 AND kind = 'recovery'`).bind(userId).first();
  return row !== null;
}

// MARK: Sign in with Apple (iOS)

/** An invite typed on the sign-in screen (Batch J); tries are limited per IP. */
const invite = z.string().max(20).optional();
/** Batch L: the sign-up screen's "I'm 18 or older and agree…" box (required for a new account). */
const adult = z.boolean().optional();

async function inviteFrom(c: Context<AppEnv>, raw: string | undefined): Promise<string | null> {
  if (!raw) return null;
  await limit(c.env, `invite-try:${await ipKey(c.env, c.req.raw)}`, 10, 3600);
  return presentedInviteHash(c.env, raw);
}

/**
 * The reason sent back when an OAuth round trip ends without a sign-in (Batch K): the app and
 * the web app show a specific message for each. Unexpected errors are logged and become `failed`.
 */
type OAuthProblem = 'cancelled' | 'expired' | 'google_unavailable' | 'failed' | 'account_deleting' | 'invite_required' | 'invite_invalid' | 'age_required';

async function problemFrom(error: unknown, provider: 'apple' | 'google'): Promise<OAuthProblem> {
  if (error instanceof HTTPException) {
    const code = ((await error.getResponse().clone().json().catch(() => ({}))) as { error?: string }).error;
    if (error.status === 403 && (code === 'invite_required' || code === 'invite_invalid' || code === 'age_required')) return code;
    if (error.status === 409) return 'account_deleting';
    if (error.status === 429) return 'failed';
  }
  log('error', 'oauth_callback_error', { provider, kind: error instanceof Error ? error.name : typeof error });
  return 'failed';
}

/** Re-authentication needs the session it re-authenticates (Batch L review: without one, a
 *  "reauth" sign-in could otherwise create an account and spend an invite). */
async function requireLiveSession(c: Context<AppEnv>) {
  const presented = presentedToken(c);
  if (!presented || !(await lookupSession(c.env, presented.token))) fail(401, 'unauthorized');
}

/** Back to whoever started the round trip, with a reason. */
function oauthFailure(c: Context<AppEnv>, platform: 'ios' | 'web', problem: OAuthProblem) {
  return platform === 'ios' ? c.redirect(`folio://auth?error=${problem}`, 302) : c.redirect(`/app?error=${problem}`, 303);
}

const appleNative = z.object({
  invite,
  adult,
  identityToken: z.string().min(20).max(4096),
  rawNonce: z.string().min(16).max(128),
  authorizationCode: z.string().max(1024).optional(),
  deviceName,
  reauth: z.boolean().optional(),
});

auth.post('/apple/native', async (c) => {
  await limit(c.env, `oauth:${await ipKey(c.env, c.req.raw)}`, 30, 3600);
  const input = await body(c, appleNative);
  if (input.reauth) await requireLiveSession(c);
  let claims;
  try {
    claims = await verifyAppleIdToken(input.identityToken, c.env.APPLE_BUNDLE_ID);
  } catch {
    fail(401, 'invalid_token');
  }
  // The app sends SHA-256(rawNonce) to Apple; the token carries that hash.
  if (!claims.nonce || !timingSafeEqual(claims.nonce, await sha256Hex(input.rawNonce))) fail(401, 'invalid_token');
  const identity = { provider: 'apple' as const, providerUserId: claims.sub, email: claims.email, emailVerified: claims.emailVerified };
  const inviteHash = await inviteFrom(c, input.invite);
  // Before the authorization code is spent: a new account needs an open invite.
  if (!input.reauth) await checkInvite(c.env, identity, inviteHash, input.adult);
  let sealed: string | null = null;
  if (input.authorizationCode && c.env.APPLE_PRIVATE_KEY) {
    const { refreshToken } = await exchangeAppleCode(c.env, input.authorizationCode, c.env.APPLE_BUNDLE_ID);
    if (refreshToken) sealed = await sealToken(c.env.TOKEN_ENCRYPTION_KEY, `${c.env.APPLE_BUNDLE_ID}|${refreshToken}`);
  }
  const { userId, isNew } = await resolveUser(c.env, { ...identity, refreshTokenSealed: sealed }, inviteHash, Date.now(), input.adult);
  return finish(c, userId, isNew, 'ios', input.deviceName, input.reauth ?? false);
});

// MARK: OAuth redirects (Apple web, Google web + iOS)

const startQuery = z.object({
  platform: z.enum(['ios', 'web']).default('web'),
  challenge: z.string().regex(/^[A-Za-z0-9_-]{43}$/).optional(),
  reauth: z.enum(['1']).optional(),
  invite,
  adult: z.enum(['1']).optional(),
});

function oauthCookie(c: Context<AppEnv>, state: string) {
  // SameSite=None: Apple returns with a cross-site POST, which a Lax cookie wouldn't join.
  setCookie(c, OAUTH_COOKIE, state, { httpOnly: true, secure: true, sameSite: 'None', path: '/', maxAge: 600, prefix: 'host' });
}

async function saveState(c: Context<AppEnv>, provider: 'apple' | 'google', query: z.infer<typeof startQuery>, verifier: string | null, nonce: string) {
  if (query.platform === 'ios' && !query.challenge) fail(400, 'invalid_request');
  // Web re-authentication remembers which session asked: Apple comes back with a cross-site
  // POST, which doesn't carry the SameSite=Lax session cookie (Batch F, DECISIONS 194).
  let reauthSession: string | null = null;
  if (query.reauth && query.platform === 'web') {
    const presented = presentedToken(c);
    const current = presented ? await lookupSession(c.env, presented.token) : null;
    if (!current) fail(401, 'unauthorized');
    reauthSession = current.sessionId;
  } else if (query.reauth) {
    reauthSession = 'yes';
  }
  // The prefix says where to send an expired or unknown state back to (Batch K); it isn't trusted for anything else.
  const state = `${query.platform === 'ios' ? 'i' : 'w'}.${randomToken(24)}`;
  const inviteHash = await inviteFrom(c, query.invite);
  await c.env.DB.prepare(
    `INSERT INTO oauth_states (state_hash, provider, platform, code_verifier, nonce, app_challenge, reauth_session, expires_at, invite_hash, adult)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)`,
  ).bind(await sha256Hex(state), provider, query.platform, verifier, nonce, query.challenge ?? null, reauthSession, Date.now() + OAUTH_TTL, inviteHash, query.adult ? 1 : 0).run();
  if (query.platform === 'web') oauthCookie(c, state);
  return state;
}

interface StateRow { provider: string; platform: 'ios' | 'web'; code_verifier: string | null; nonce: string; app_challenge: string | null; reauth_session: string | null; expires_at: number; invite_hash: string | null; adult: number }

/**
 * Takes (and deletes) a state row; web flows must also present the matching cookie. Null for an
 * unknown, replayed or expired state (10 minutes).
 */
async function takeState(c: Context<AppEnv>, provider: 'apple' | 'google', state: string | undefined): Promise<StateRow | null> {
  if (!state || state.length > 100) return null;
  const row = await c.env.DB.prepare('DELETE FROM oauth_states WHERE state_hash = ?1 AND provider = ?2 RETURNING *')
    .bind(await sha256Hex(state), provider).first<StateRow>();
  if (!row || row.expires_at < Date.now()) return null;
  if (row.platform === 'web') {
    const cookie = getCookie(c, OAUTH_COOKIE, 'host');
    if (!cookie || !timingSafeEqual(cookie, state)) return null;
    deleteCookie(c, OAUTH_COOKIE, { path: '/', secure: true, prefix: 'host' });
  }
  return row;
}

/** Which side a state was made for, from its prefix (states without one are web). */
function statePlatform(state: string | undefined): 'ios' | 'web' {
  return state?.startsWith('i.') ? 'ios' : 'web';
}

/** Ends a web OAuth round trip on the web app; `reauthSession` is the session that asked. */
async function finishWeb(c: Context<AppEnv>, userId: string, reauthSession: string | null) {
  if (reauthSession) {
    const current = await c.env.DB.prepare('SELECT user_id, expires_at FROM sessions WHERE id = ?1').bind(reauthSession).first<{ user_id: string; expires_at: number }>();
    if (!current || current.user_id !== userId || current.expires_at <= Date.now()) return c.redirect('/app/settings/account?error=reauth', 303);
    await c.env.DB.prepare('UPDATE sessions SET reauth_at = ?2 WHERE id = ?1').bind(reauthSession, Date.now()).run();
    return c.redirect('/app/settings/account?reauth=1', 303);
  }
  const session = await createSession(c.env, userId, 'web', browserName(c.req.header('user-agent')));
  setSessionCookie(c, session.token);
  return c.redirect('/app', 303);
}

function browserName(agent = ''): string {
  const browser = /Edg\//.test(agent) ? 'Edge' : /Firefox\//.test(agent) ? 'Firefox' : /Chrome\//.test(agent) ? 'Chrome' : /Safari\//.test(agent) ? 'Safari' : 'Browser';
  const os = /Mac OS X/.test(agent) && !/iPhone|iPad/.test(agent) ? 'macOS' : /iPhone/.test(agent) ? 'iOS' : /iPad/.test(agent) ? 'iPadOS'
    : /Android/.test(agent) ? 'Android' : /Windows/.test(agent) ? 'Windows' : /Linux/.test(agent) ? 'Linux' : '';
  return os ? `${browser} on ${os}` : browser;
}

auth.get('/google/start', async (c) => {
  await limit(c.env, `oauth:${await ipKey(c.env, c.req.raw)}`, 30, 3600);
  const query = startQuery.safeParse(c.req.query());
  if (!query.success || !c.env.GOOGLE_CLIENT_ID) fail(400, 'invalid_request');
  const verifier = randomToken(32);
  const nonce = randomToken(16);
  const state = await saveState(c, 'google', query.data, verifier, nonce);
  return c.redirect(googleAuthorizeURL(c.env, state, await sha256Base64url(verifier), nonce), 302);
});

auth.get('/callback/google', async (c) => {
  await limit(c.env, `oauth:${await ipKey(c.env, c.req.raw)}`, 30, 3600);
  const stateParam = c.req.query('state');
  const row = await takeState(c, 'google', stateParam);
  if (!row) {
    log('warn', 'google_callback_failed', { step: 'state' });
    return oauthFailure(c, statePlatform(stateParam), 'expired');
  }
  const code = c.req.query('code');
  if (!code || code.length > 2048) return oauthFailure(c, row.platform, 'cancelled');
  const exchanged = await exchangeGoogleCode(c.env, code, row.code_verifier ?? '');
  if ('problem' in exchanged) return oauthFailure(c, row.platform, exchanged.problem === 'config' ? 'google_unavailable' : 'expired');
  let claims;
  try {
    claims = await verifyGoogleIdToken(c.env, exchanged.idToken, row.nonce);
  } catch (error) {
    log('warn', 'google_callback_failed', { step: 'id_token', kind: error instanceof Error ? error.name : 'unknown' });
    return oauthFailure(c, row.platform, 'failed');
  }
  let resolved;
  try {
    resolved = await resolveUser(c.env, { provider: 'google', providerUserId: claims.sub, email: claims.email, emailVerified: claims.emailVerified }, row.invite_hash, Date.now(), row.adult === 1);
  } catch (error) {
    // A new account without an open invite goes back to the sign-in screen, which asks for one.
    return oauthFailure(c, row.platform, await problemFrom(error, 'google'));
  }
  const { userId, isNew } = resolved;
  if (row.platform === 'web') return finishWeb(c, userId, row.reauth_session);
  // iOS: a 60-second, single-use code the app trades for a session, bound to the app's own
  // verifier so another app claiming the folio:// scheme can't use it.
  const handoff = randomToken(32);
  await c.env.DB.prepare(
    'INSERT INTO handoff_codes (code_hash, user_id, app_challenge, is_new, reauth_session, expires_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)',
  ).bind(await sha256Hex(handoff), userId, row.app_challenge, isNew ? 1 : 0, row.reauth_session, Date.now() + HANDOFF_TTL).run();
  return c.redirect(`folio://auth?code=${handoff}`, 302);
});

const exchange = z.object({
  code: z.string().min(20).max(100),
  verifier: z.string().regex(/^[A-Za-z0-9_-]{43,128}$/),
  deviceName,
  reauth: z.boolean().optional(),
});

auth.post('/exchange', async (c) => {
  await limit(c.env, `oauth:${await ipKey(c.env, c.req.raw)}`, 30, 3600);
  const input = await body(c, exchange);
  const row = await c.env.DB.prepare('DELETE FROM handoff_codes WHERE code_hash = ?1 RETURNING *')
    .bind(await sha256Hex(input.code)).first<{ user_id: string; app_challenge: string; is_new: number; expires_at: number }>();
  if (!row || row.expires_at < Date.now()) fail(400, 'invalid_code');
  if (!timingSafeEqual(row.app_challenge, await sha256Base64url(input.verifier))) fail(400, 'invalid_code');
  return finish(c, row.user_id, row.is_new === 1, 'ios', input.deviceName, input.reauth ?? false);
});

auth.get('/apple/start', async (c) => {
  await limit(c.env, `oauth:${await ipKey(c.env, c.req.raw)}`, 30, 3600);
  const query = startQuery.safeParse({ ...c.req.query(), platform: 'web' });
  if (!query.success) fail(400, 'invalid_request');
  const nonce = randomToken(16);
  const state = await saveState(c, 'apple', query.data, null, nonce);
  return c.redirect(appleAuthorizeURL(c.env, state, nonce), 302);
});

// Apple posts the result back (response_mode=form_post), so this is a cross-site POST: it's
// exempt from the Origin check and bound to the browser by the state cookie instead.
auth.post('/callback/apple', async (c) => {
  await limit(c.env, `oauth:${await ipKey(c.env, c.req.raw)}`, 30, 3600);
  const form = await c.req.parseBody();
  const row = await takeState(c, 'apple', typeof form.state === 'string' ? form.state : undefined);
  if (!row) return oauthFailure(c, 'web', 'expired');
  const code = typeof form.code === 'string' ? form.code : null;
  if (!code || code.length > 2048) return c.redirect('/app?error=cancelled', 303);
  const redirectUri = `${c.env.APP_ORIGIN}/api/auth/callback/apple`;
  const { refreshToken, idToken } = await exchangeAppleCode(c.env, code, c.env.APPLE_SERVICES_ID, redirectUri);
  if (!idToken) return c.redirect('/app?error=failed', 303);
  let claims;
  try {
    claims = await verifyAppleIdToken(idToken, c.env.APPLE_SERVICES_ID);
  } catch {
    return c.redirect('/app?error=failed', 303);
  }
  if (claims.nonce !== row.nonce) return c.redirect('/app?error=failed', 303);
  const sealed = refreshToken ? await sealToken(c.env.TOKEN_ENCRYPTION_KEY, `${c.env.APPLE_SERVICES_ID}|${refreshToken}`) : null;
  let userId: string;
  try {
    ({ userId } = await resolveUser(c.env, {
      provider: 'apple', providerUserId: claims.sub, email: claims.email, emailVerified: claims.emailVerified, refreshTokenSealed: sealed,
    }, row.invite_hash, Date.now(), row.adult === 1));
  } catch (error) {
    return oauthFailure(c, 'web', await problemFrom(error, 'apple'));
  }
  return finishWeb(c, userId, row.reauth_session);
});

// Batch M: Sign in with Apple server-to-server notifications (consent revoked, Apple Account
// deleted, Hide My Email forwarding). Apple's servers post `{"payload": "<JWT>"}`, no cookie
// or Origin; the signature is the authentication. Registered on the App ID in the developer
// portal (owner step).
auth.post('/apple/notifications', async (c) => {
  await limit(c.env, `apple-notify:${await ipKey(c.env, c.req.raw)}`, 120, 3600);
  const input = await body(c, z.object({ payload: z.string().min(1).max(8192) }));
  let event;
  try {
    event = await verifyAppleNotification(c.env, input.payload);
  } catch {
    log('warn', 'apple_notification_rejected');
    fail(400, 'invalid_notification');
  }
  await applyAppleEvent(c.env, event);
  return c.json({ ok: true });
});

// MARK: Email code

const emailStart = z.object({
  email: z.email().max(254),
  client: z.enum(['ios', 'web']),
  turnstileToken: z.string().max(2048).optional(),
});

auth.post('/email/start', async (c) => {
  const ip = clientIP(c.req.raw);
  await limit(c.env, `email-start-ip:${await ipKey(c.env, c.req.raw)}`, 10, 3600);
  const input = await body(c, emailStart);
  const email = normaliseEmail(input.email);
  // Counters are keyed by an HMAC of the address (Batch L review: a plain hash is reversible by
  // guessing addresses). 3 codes per 15 minutes and 10 per day per address.
  const emailKey = await hmacHex(c.env.OTP_PEPPER, `email|${email}`);
  await limit(c.env, `email-start:${emailKey}`, 3, 15 * 60);
  await limit(c.env, `email-day:${emailKey}`, 10, 86_400);
  // Any browser request (it carries an Origin) needs Turnstile, whatever `client` it claims.
  // Until the web app ships with Turnstile (Batch F) there's no secret, so it stays closed.
  const fromBrowser = input.client === 'web' || c.req.header('origin') !== undefined;
  if (fromBrowser && !c.env.TURNSTILE_SECRET) fail(503, 'web_email_disabled');
  if (fromBrowser && !(await verifyTurnstile(c.env, input.turnstileToken, ip))) fail(400, 'turnstile');

  // App Review's demo address gets a fixed code from a Worker secret instead of an email
  // (SPEC §12); switch off with REVIEW_ENABLED=false after approval.
  const isReview = c.env.REVIEW_ENABLED === 'true' && !!c.env.REVIEW_CODE && email === normaliseEmail(c.env.REVIEW_EMAIL);
  const code = isReview ? c.env.REVIEW_CODE! : sixDigitCode();
  const now = Date.now();
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM verification_codes WHERE email = ?1').bind(email),
    c.env.DB.prepare('INSERT INTO verification_codes (id, email, code_hash, attempts, created_at, expires_at) VALUES (?1, ?2, ?3, 0, ?4, ?5)')
      .bind(crypto.randomUUID(), email, await hmacHex(c.env.OTP_PEPPER, `${email}|${code}`), now, now + CODE_TTL),
  ]);
  if (!isReview) {
    const sender = emailSender(c.env);
    if (sender) c.executionCtx.waitUntil(sender.send(signInCodeEmail(email, code), `code-${await sha256Hex(`${email}|${now}`)}`));
    else log('error', 'email_not_configured');
  }
  // The same answer whether or not an account exists (no enumeration).
  return c.json({ ok: true });
});

const emailVerify = z.object({
  email: z.email().max(254),
  code: z.string().regex(/^\d{6}$/),
  client: z.enum(['ios', 'web']),
  deviceName: deviceName.optional(),
  reauth: z.boolean().optional(),
  invite,
  adult,
});

auth.post('/email/verify', async (c) => {
  await limit(c.env, `email-verify-ip:${await ipKey(c.env, c.req.raw)}`, 20, 3600);
  const input = await body(c, emailVerify);
  const email = normaliseEmail(input.email);
  // Batch L review: at most 20 code checks per address per day, from any number of networks,
  // so a 6-digit code can't be ground down over time (5 per code still applies).
  await limit(c.env, `email-verify-day:${await hmacHex(c.env.OTP_PEPPER, `email|${email}`)}`, 20, 86_400);
  if (input.reauth) await requireLiveSession(c);
  const row = await c.env.DB.prepare(
    `UPDATE verification_codes SET attempts = attempts + 1
     WHERE id = (SELECT id FROM verification_codes WHERE email = ?1 AND expires_at > ?2 ORDER BY created_at DESC LIMIT 1)
     RETURNING id, code_hash, attempts`,
  ).bind(email, Date.now()).first<{ id: string; code_hash: string; attempts: number }>();
  if (!row) fail(400, 'invalid_code');
  if (row.attempts > CODE_ATTEMPTS) {
    await c.env.DB.prepare('DELETE FROM verification_codes WHERE id = ?1').bind(row.id).run();
    fail(400, 'invalid_code');
  }
  const presented = await hmacHex(c.env.OTP_PEPPER, `${email}|${input.code}`);
  if (!timingSafeEqual(presented, row.code_hash)) fail(400, 'invalid_code');
  const identity = { provider: 'email' as const, providerUserId: email, email, emailVerified: true };
  const inviteHash = await inviteFrom(c, input.invite);
  // The code stays valid while the app asks for an invite (Batch J); it still counts attempts.
  if (!input.reauth) await checkInvite(c.env, identity, inviteHash, input.adult);
  await c.env.DB.prepare('DELETE FROM verification_codes WHERE email = ?1').bind(email).run();
  const { userId, isNew } = await resolveUser(c.env, identity, inviteHash, Date.now(), input.adult);
  const device = input.deviceName ?? (input.client === 'web' ? browserName(c.req.header('user-agent')) : 'iPhone');
  return finish(c, userId, isNew, input.client, device, input.reauth ?? false);
});

// MARK: Session

/** Whether this browser is signed in, without an error status (the web app's first call). */
auth.get('/session', async (c) => {
  const presented = presentedToken(c);
  const session = presented ? await lookupSession(c.env, presented.token) : null;
  return c.json({ signedIn: session !== null });
});

auth.post('/sign-out', requireSession, async (c) => {
  await c.env.DB.prepare('DELETE FROM sessions WHERE id = ?1').bind(c.var.session.sessionId).run();
  clearSessionCookie(c);
  return c.json({ ok: true });
});
