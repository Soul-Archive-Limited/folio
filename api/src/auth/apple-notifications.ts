import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { Env } from '../env';
import { log } from '../lib/errors';

const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export type AppleEventType = 'email-enabled' | 'email-disabled' | 'consent-revoked' | 'account-deleted';

export interface AppleEvent {
  type: AppleEventType | string;
  sub: string;
  /** Milliseconds. */
  eventTime: number;
}

/**
 * Verifies a Sign in with Apple server-to-server notification (Batch M): an RS256 JWT signed
 * by Apple, issued for our App ID (or the web Services ID), with the change in `events`.
 * Apple documents `events` as an object; older deliveries sent it as a JSON string, so both
 * are read. `event_time` is seconds in Apple's examples; milliseconds are accepted too.
 */
export async function verifyAppleNotification(env: Env, token: string, now = Date.now()): Promise<AppleEvent> {
  const { payload } = await jwtVerify(token, appleKeys, {
    issuer: 'https://appleid.apple.com',
    audience: [env.APPLE_BUNDLE_ID, env.APPLE_SERVICES_ID],
    algorithms: ['RS256'],
  });
  if (typeof payload.iat === 'number' && payload.iat * 1000 > now + 5 * 60_000) throw new Error('issued in the future');
  const raw = typeof payload.events === 'string' ? JSON.parse(payload.events) as unknown : payload.events;
  if (!raw || typeof raw !== 'object') throw new Error('no events');
  const events = raw as Record<string, unknown>;
  if (typeof events.type !== 'string' || typeof events.sub !== 'string' || events.sub.length === 0) throw new Error('bad events');
  const time = Number(events.event_time);
  const eventTime = !Number.isFinite(time) || time <= 0 ? now : time < 1e12 ? time * 1000 : time;
  return { type: events.type, sub: events.sub, eventTime: Math.min(eventTime, now) };
}

/**
 * Applies one verified event. Every branch is idempotent, so a repeated delivery changes
 * nothing new:
 * - `consent-revoked` ("Stop using Apple ID"): every session that existed when it happened
 *   ends, on every device. The Apple link stays, so signing in with Apple again reaches the
 *   same diary. Sessions made after the event (a fresh sign-in) are left alone, so a late or
 *   replayed delivery can't sign anyone out of a new session.
 * - `account-deleted` (the Apple Account itself is gone, so this Apple ID can never sign in
 *   again): the Apple link is removed and the sessions end. If Apple was the only way in, the
 *   encrypted diary on the server can never be reached again, so it is wiped as if the person
 *   had deleted their Folio account (no confirmation email: the relay address is gone too).
 * - `email-enabled` / `email-disabled` (Hide My Email forwarding): Folio only ever emails
 *   sign-in codes and a deletion confirmation, so nothing is stored; noted in the log only.
 */
export async function applyAppleEvent(env: Env, event: AppleEvent): Promise<'ended' | 'unlinked' | 'wiped' | 'noted' | 'unknown_user'> {
  const db = env.DB;
  if (event.type !== 'consent-revoked' && event.type !== 'account-deleted') {
    log('info', 'apple_notification', { type: event.type.slice(0, 32) });
    return 'noted';
  }
  const link = await db.prepare(`SELECT id, user_id FROM accounts WHERE provider = 'apple' AND provider_user_id = ?1`)
    .bind(event.sub).first<{ id: string; user_id: string }>();
  if (!link) {
    log('info', 'apple_notification', { type: event.type, user: false });
    return 'unknown_user';
  }
  const userId = link.user_id;
  const hub = env.USER_HUB.get(env.USER_HUB.idFromName(userId));

  if (event.type === 'account-deleted') {
    const others = await db.prepare(`SELECT COUNT(*) AS n FROM accounts WHERE user_id = ?1 AND id != ?2`).bind(userId, link.id).first<{ n: number }>();
    if ((others?.n ?? 0) === 0) {
      const marked = await db.prepare('UPDATE users SET deleting = 1 WHERE id = ?1 AND deleting = 0 RETURNING id').bind(userId).first();
      // The refresh token is already void at Apple; drop it so the wipe doesn't try to revoke it.
      await db.prepare('UPDATE accounts SET refresh_token_enc = NULL WHERE id = ?1').bind(link.id).run();
      if (marked) await hub.startWipe(userId, null);
      log('info', 'apple_notification', { type: event.type, outcome: 'wiped' });
      return 'wiped';
    }
    await db.prepare('DELETE FROM accounts WHERE id = ?1').bind(link.id).run();
  }
  // consent-revoked keeps the refresh token: a replay must never drop one a later sign-in stored,
  // and revoking a void token at deletion is harmless.

  const ended = await db.prepare('DELETE FROM sessions WHERE user_id = ?1 AND created_at <= ?2 RETURNING id')
    .bind(userId, event.eventTime).all<{ id: string }>();
  await Promise.all(ended.results.map((row) => hub.disconnect(row.id)));
  const outcome = event.type === 'account-deleted' ? 'unlinked' : 'ended';
  log('info', 'apple_notification', { type: event.type, outcome, sessions: ended.results.length });
  return outcome;
}
