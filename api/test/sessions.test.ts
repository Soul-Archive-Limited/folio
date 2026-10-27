import { env, SELF } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { createSession } from '../src/lib/session';
import { api, makeUser, ORIGIN, secondSession } from './helpers';

describe('sessions and CSRF (SPEC §10.2, §13)', () => {
  it('needs a valid bearer token', async () => {
    expect((await api('/account/me')).status).toBe(401);
    expect((await api('/account/me', { token: 'x'.repeat(43) })).status).toBe(401);
    const user = await makeUser();
    const me = await api('/account/me', { token: user.token });
    expect(me.status).toBe(200);
    expect(me.headers.get('cache-control')).toBe('no-store');
    expect(me.headers.get('x-content-type-options')).toBe('nosniff');
  });

  it('expired sessions stop working', async () => {
    const user = await makeUser();
    await env.DB.prepare('UPDATE sessions SET expires_at = 1 WHERE id = ?1').bind(user.sessionId).run();
    expect((await api('/account/me', { token: user.token })).status).toBe(401);
  });

  it('sliding expiry: a session seen more than a day ago is extended on use', async () => {
    const user = await makeUser();
    await env.DB.prepare('UPDATE sessions SET last_seen_at = 0, expires_at = ?2 WHERE id = ?1').bind(user.sessionId, Date.now() + 60_000).run();
    await api('/account/me', { token: user.token });
    const row = await env.DB.prepare('SELECT expires_at FROM sessions WHERE id = ?1').bind(user.sessionId).first<{ expires_at: number }>();
    expect(row!.expires_at).toBeGreaterThan(Date.now() + 29 * 86_400_000);
  });

  it('sign out ends only this session', async () => {
    const user = await makeUser();
    const other = await secondSession(user);
    expect((await api('/auth/sign-out', { method: 'POST', token: user.token })).status).toBe(200);
    expect((await api('/account/me', { token: user.token })).status).toBe(401);
    expect((await api('/account/me', { token: other.token })).status).toBe(200);
  });

  it('cookie sessions: state changes need the app Origin', async () => {
    const user = await makeUser();
    const web = await createSession(env, user.userId, 'web', 'Safari on Mac');
    const cookie = `__Host-folio_session=${web.token}`;
    const noOrigin = await SELF.fetch(`${ORIGIN}/api/auth/sign-out`, { method: 'POST', headers: { cookie } });
    expect(noOrigin.status).toBe(403);
    const evil = await SELF.fetch(`${ORIGIN}/api/auth/sign-out`, { method: 'POST', headers: { cookie, origin: 'https://evil.example' } });
    expect(evil.status).toBe(403);
    const me = await SELF.fetch(`${ORIGIN}/api/account/me`, { headers: { cookie } });
    expect(me.status).toBe(200);
    const ok = await SELF.fetch(`${ORIGIN}/api/auth/sign-out`, { method: 'POST', headers: { cookie, origin: ORIGIN } });
    expect(ok.status).toBe(200);
  });

  it('unknown routes are a JSON 404', async () => {
    const response = await api('/nope');
    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: 'not_found' });
  });
});

describe('devices (SPEC §6.9)', () => {
  it('lists this account\'s devices and signs others out', async () => {
    const user = await makeUser();
    const mac = await secondSession(user, 'Chrome on Mac');
    const list = await (await api('/account/devices', { token: user.token })).json<{ devices: { id: string; name: string; current: boolean }[] }>();
    expect(list.devices.map((d) => d.name).sort()).toEqual(['Chrome on Mac', 'Test iPhone']);
    expect(list.devices.find((d) => d.current)?.id).toBe(user.sessionId);
    expect((await api('/account/devices/sign-out-others', { method: 'POST', token: user.token })).status).toBe(200);
    expect((await api('/account/me', { token: mac.token })).status).toBe(401);
  });

  it('can\'t sign out another user\'s device', async () => {
    const me = await makeUser();
    const stranger = await makeUser();
    expect((await api(`/account/devices/${stranger.sessionId}`, { method: 'DELETE', token: me.token })).status).toBe(404);
    expect((await api('/account/me', { token: stranger.token })).status).toBe(200);
  });
});

describe('nightly clean-up', () => {
  it('removes expired codes, states, sessions and old counters, and nothing live', async () => {
    const { cleanUp } = await import('../src/index');
    const live = await makeUser();
    const old = await makeUser();
    await env.DB.prepare('UPDATE sessions SET expires_at = 1 WHERE id = ?1').bind(old.sessionId).run();
    await env.DB.prepare(`INSERT INTO verification_codes (id, email, code_hash, created_at, expires_at) VALUES ('c1', 'a@b.co', 'h', 0, 1)`).run();
    await env.DB.prepare(`INSERT INTO rate_limits (key, window_start, count) VALUES ('old', 0, 3)`).run();
    await cleanUp(env);
    expect(await env.DB.prepare('SELECT id FROM sessions WHERE id = ?1').bind(old.sessionId).first()).toBeNull();
    expect(await env.DB.prepare(`SELECT id FROM verification_codes WHERE id = 'c1'`).first()).toBeNull();
    expect(await env.DB.prepare(`SELECT key FROM rate_limits WHERE key = 'old'`).first()).toBeNull();
    expect((await api('/account/me', { token: live.token })).status).toBe(200);
  });
});

describe('/vibesec hardening', () => {
  it('caps JSON bodies at 64 KB outside sync push', async () => {
    const response = await api('/auth/email/start', { method: 'POST', body: JSON.stringify({ email: 'a@b.co', client: 'ios', pad: 'x'.repeat(70_000) }), headers: { 'content-type': 'application/json' } });
    expect(response.status).toBe(413);
  });

  it('a browser request needs Turnstile even if it claims to be the app', async () => {
    const response = await api('/auth/email/start', { method: 'POST', json: { email: 'sneaky@example.com', client: 'ios' }, headers: { origin: ORIGIN } });
    expect(await response.json()).toEqual({ error: 'turnstile' });
  });

  it('refuses a live socket from another origin', async () => {
    const user = await makeUser();
    const response = await SELF.fetch(`${ORIGIN}/api/live`, { headers: { upgrade: 'websocket', authorization: `Bearer ${user.token}`, origin: 'https://evil.example' } });
    expect(response.status).toBe(403);
  });
});
