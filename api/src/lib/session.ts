import type { Context, MiddlewareHandler } from 'hono';
import { getCookie, setCookie, deleteCookie } from 'hono/cookie';
import type { AppEnv, Env, SessionInfo } from '../env';
import { randomToken, sha256Hex } from './crypto';
import { fail } from './errors';

/** Sent as `__Host-folio_session` (Hono adds the prefix). */
export const SESSION_COOKIE = 'folio_session';
export const SESSION_DAYS = 30;
const DAY = 86_400_000;

export interface NewSession {
  token: string;
  sessionId: string;
  expiresAt: number;
}

/** Creates a session: a 256-bit opaque token; only its SHA-256 is stored (SPEC §10.2). */
export async function createSession(env: Env, userId: string, platform: 'ios' | 'web', deviceName: string, now = Date.now()): Promise<NewSession> {
  const token = randomToken(32);
  const sessionId = crypto.randomUUID();
  const expiresAt = now + SESSION_DAYS * DAY;
  await env.DB.prepare(
    `INSERT INTO sessions (id, user_id, token_hash, device_name, platform, created_at, last_seen_at, expires_at, reauth_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6, ?7, ?6)`,
  ).bind(sessionId, userId, await sha256Hex(token), deviceName, platform, now, expiresAt).run();
  return { token, sessionId, expiresAt };
}

/** Bearer header (iOS) or the `__Host-` cookie (web). */
export function presentedToken(c: Context<AppEnv>): { token: string; viaCookie: boolean } | null {
  const header = c.req.header('authorization');
  if (header?.startsWith('Bearer ')) return { token: header.slice(7).trim(), viaCookie: false };
  const cookie = getCookie(c, SESSION_COOKIE, 'host');
  return cookie ? { token: cookie, viaCookie: true } : null;
}

export async function lookupSession(env: Env, token: string, now = Date.now()): Promise<SessionInfo | null> {
  if (token.length < 20 || token.length > 100) return null;
  const row = await env.DB.prepare(
    `SELECT s.id, s.user_id, s.platform, s.last_seen_at, s.expires_at, s.reauth_at, u.deleting
     FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?1`,
  ).bind(await sha256Hex(token)).first<{ id: string; user_id: string; platform: 'ios' | 'web'; last_seen_at: number; expires_at: number; reauth_at: number | null; deleting: number }>();
  if (!row || row.expires_at <= now || row.deleting) return null;
  // Sliding 30-day expiry, written at most once a day to spare D1 writes.
  if (now - row.last_seen_at > DAY) {
    await env.DB.prepare('UPDATE sessions SET last_seen_at = ?2, expires_at = ?3 WHERE id = ?1')
      .bind(row.id, now, now + SESSION_DAYS * DAY).run();
  }
  return { sessionId: row.id, userId: row.user_id, platform: row.platform, reauthAt: row.reauth_at };
}

/** Requires a valid session; sets `c.var.session`. */
export const requireSession: MiddlewareHandler<AppEnv> = async (c, next) => {
  const presented = presentedToken(c);
  const session = presented ? await lookupSession(c.env, presented.token) : null;
  if (!session) fail(401, 'unauthorized');
  c.set('session', session);
  await next();
};

export function setSessionCookie(c: Context<AppEnv>, token: string) {
  setCookie(c, SESSION_COOKIE, token, {
    httpOnly: true, secure: true, sameSite: 'Lax', path: '/', maxAge: SESSION_DAYS * 86_400, prefix: 'host',
  });
}

export function clearSessionCookie(c: Context<AppEnv>) {
  deleteCookie(c, SESSION_COOKIE, { path: '/', secure: true, prefix: 'host' });
}
