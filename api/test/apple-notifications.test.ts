import { env, runDurableObjectAlarm } from 'cloudflare:test';
import { SignJWT, exportJWK, generateKeyPair } from 'jose';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { createSession } from '../src/lib/session';
import { api, makeUser } from './helpers';

// Batch M: Sign in with Apple server-to-server notifications.
const { publicKey, privateKey } = await generateKeyPair('RS256');
const jwk = { ...(await exportJWK(publicKey)), kid: 'notify', alg: 'RS256', use: 'sig' };
const { privateKey: stranger } = await generateKeyPair('RS256');

beforeAll(() => {
  vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (url === 'https://appleid.apple.com/auth/keys') return Response.json({ keys: [jwk] });
    throw new Error(`unexpected fetch ${url}`);
  });
});
afterEach(() => vi.clearAllMocks());

function notification(events: Record<string, unknown> | string, { audience = 'com.devilsense.folio', key = privateKey, issuer = 'https://appleid.apple.com', iat }: {
  audience?: string; key?: CryptoKey; issuer?: string; iat?: number;
} = {}) {
  return new SignJWT({ events, jti: crypto.randomUUID() }).setProtectedHeader({ alg: 'RS256', kid: 'notify' })
    .setIssuer(issuer).setAudience(audience).setIssuedAt(iat ?? Math.floor(Date.now() / 1000)).sign(key);
}

const post = (payload: string) => api('/auth/apple/notifications', { method: 'POST', json: { payload } });

/** A user whose only sign-in method is Apple, with two sessions created a minute ago. */
async function appleUser(sub: string, alsoEmail = false) {
  const user = await makeUser();
  if (!alsoEmail) await env.DB.prepare(`DELETE FROM accounts WHERE user_id = ?1`).bind(user.userId).run();
  await env.DB.prepare(`INSERT INTO accounts (id, user_id, provider, provider_user_id, email, refresh_token_enc, created_at) VALUES (?1, ?2, 'apple', ?3, NULL, 'sealed', ?4)`)
    .bind(crypto.randomUUID(), user.userId, sub, Date.now()).run();
  await createSession(env, user.userId, 'web', 'Mac');
  await env.DB.prepare('UPDATE sessions SET created_at = ?2 WHERE user_id = ?1').bind(user.userId, Date.now() - 60_000).run();
  return user;
}

const sessionCount = async (userId: string) =>
  (await env.DB.prepare('SELECT COUNT(*) AS n FROM sessions WHERE user_id = ?1').bind(userId).first<{ n: number }>())?.n;

describe('Sign in with Apple notifications', () => {
  it('consent-revoked ends every existing session but keeps the account, link and newer sessions', async () => {
    const user = await appleUser('apple-revoke');
    const eventTime = Math.floor(Date.now() / 1000);
    const later = await createSession(env, user.userId, 'ios', 'iPhone');
    await env.DB.prepare('UPDATE sessions SET created_at = ?2 WHERE id = ?1').bind(later.sessionId, Date.now() + 5_000).run();

    const response = await post(await notification({ type: 'consent-revoked', sub: 'apple-revoke', event_time: eventTime }));
    expect(response.status).toBe(200);
    expect(await sessionCount(user.userId)).toBe(1);
    expect((await api('/account/me', { token: user.token })).status).toBe(401);
    expect((await api('/account/me', { token: later.token })).status).toBe(200);
    const link = await env.DB.prepare(`SELECT refresh_token_enc FROM accounts WHERE provider = 'apple' AND provider_user_id = 'apple-revoke'`).first<{ refresh_token_enc: string }>();
    expect(link?.refresh_token_enc).toBe('sealed');

    // A replay changes nothing for the newer session.
    expect((await post(await notification({ type: 'consent-revoked', sub: 'apple-revoke', event_time: eventTime }))).status).toBe(200);
    expect((await api('/account/me', { token: later.token })).status).toBe(200);
  });

  it('accepts events sent as a JSON string and event_time in milliseconds', async () => {
    const user = await appleUser('apple-string');
    const events = JSON.stringify({ type: 'consent-revoked', sub: 'apple-string', event_time: Date.now() });
    expect((await post(await notification(events))).status).toBe(200);
    expect(await sessionCount(user.userId)).toBe(0);
  });

  it('account-deleted with another sign-in method unlinks Apple and ends sessions', async () => {
    const user = await appleUser('apple-gone', true);
    expect((await post(await notification({ type: 'account-deleted', sub: 'apple-gone', event_time: Math.floor(Date.now() / 1000) }))).status).toBe(200);
    const providers = await env.DB.prepare('SELECT provider FROM accounts WHERE user_id = ?1').bind(user.userId).all<{ provider: string }>();
    expect(providers.results.map((p) => p.provider)).toEqual(['email']);
    expect(await sessionCount(user.userId)).toBe(0);
    expect(await env.DB.prepare('SELECT id FROM users WHERE id = ?1').bind(user.userId).first()).not.toBeNull();
  });

  it('account-deleted when Apple was the only way in wipes the account', async () => {
    const user = await appleUser('apple-only');
    await env.DB.prepare(`INSERT INTO records (user_id, id, type, version, ciphertext, nonce, client_updated_at, deleted, size) VALUES (?1, ?2, 'entry', 1, 'eA==', 'eA==', 1, 0, 1)`)
      .bind(user.userId, crypto.randomUUID()).run();
    expect((await post(await notification({ type: 'account-deleted', sub: 'apple-only', event_time: Math.floor(Date.now() / 1000) }))).status).toBe(200);
    expect((await api('/account/me', { token: user.token })).status).toBe(401);
    const hub = env.USER_HUB.get(env.USER_HUB.idFromName(user.userId));
    for (let i = 0; i < 100 && await env.DB.prepare('SELECT id FROM users WHERE id = ?1').bind(user.userId).first(); i++) {
      await runDurableObjectAlarm(hub);
      await new Promise((r) => setTimeout(r, 20));
    }
    expect(await env.DB.prepare('SELECT id FROM users WHERE id = ?1').bind(user.userId).first()).toBeNull();
    expect(await env.DB.prepare(`SELECT id FROM accounts WHERE provider_user_id = 'apple-only'`).first()).toBeNull();
    expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM records WHERE user_id = ?1').bind(user.userId).first<{ n: number }>()).toEqual({ n: 0 });
    // Apple wasn't asked to revoke a token it has already voided.
    expect(vi.mocked(fetch).mock.calls.some(([input]) => String(input instanceof Request ? input.url : input).includes('/auth/revoke'))).toBe(false);
  });

  it('notes email forwarding changes without storing anything', async () => {
    const user = await appleUser('apple-mail');
    for (const type of ['email-disabled', 'email-enabled']) {
      const token = await notification({ type, sub: 'apple-mail', email: 'x@privaterelay.appleid.com', is_private_email: 'true', event_time: 1 });
      expect((await post(token)).status).toBe(200);
    }
    expect(await sessionCount(user.userId)).toBe(2);
  });

  it('answers 200 for an Apple ID Folio has never seen', async () => {
    expect((await post(await notification({ type: 'consent-revoked', sub: 'nobody', event_time: 1 }))).status).toBe(200);
  });

  it('accepts the web Services ID as the audience', async () => {
    const user = await appleUser('apple-web');
    const token = await notification({ type: 'consent-revoked', sub: 'apple-web', event_time: Math.floor(Date.now() / 1000) }, { audience: env.APPLE_SERVICES_ID });
    expect((await post(token)).status).toBe(200);
    expect(await sessionCount(user.userId)).toBe(0);
  });

  it('rejects forged, foreign and malformed notifications and changes nothing', async () => {
    const user = await appleUser('apple-target');
    const events = { type: 'account-deleted', sub: 'apple-target', event_time: Math.floor(Date.now() / 1000) };
    const bad = [
      await notification(events, { key: stranger }),
      await notification(events, { audience: 'com.evil.app' }),
      await notification(events, { issuer: 'https://evil.example' }),
      await notification(events, { iat: Math.floor(Date.now() / 1000) + 3600 }),
      await notification({ type: 'account-deleted' }),
      'not-a-jwt',
    ];
    for (const payload of bad) expect((await post(payload)).status).toBe(400);
    expect((await api('/auth/apple/notifications', { method: 'POST', json: { nope: 1 } })).status).toBe(400);
    expect(await sessionCount(user.userId)).toBe(2);
    expect(await env.DB.prepare(`SELECT id FROM accounts WHERE provider_user_id = 'apple-target'`).first()).not.toBeNull();
  });
});
