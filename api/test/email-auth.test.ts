import { createExecutionContext, env, waitOnExecutionContext } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import worker from '../src/index';
import { OutboxSender } from '../src/lib/email';
import { api, ORIGIN } from './helpers';

const start = (email: string, extra: Record<string, unknown> = {}, ip = '203.0.113.1') =>
  api('/auth/email/start', { method: 'POST', json: { email, client: 'ios', ...extra }, headers: { 'cf-connecting-ip': ip } });
const verify = (email: string, code: string, extra: Record<string, unknown> = {}, ip = '203.0.113.2') =>
  api('/auth/email/verify', { method: 'POST', json: { email, code, client: 'ios', deviceName: 'iPhone 17 Pro', ...extra }, headers: { 'cf-connecting-ip': ip } });

function sentCode(email: string): string {
  const message = OutboxSender.sent.get(email);
  const code = message?.subject.match(/^(\d{6})/)?.[1];
  if (!code) throw new Error('no code sent');
  return code;
}

describe('email sign-in (SPEC §10.2)', () => {
  it('sends a 6-digit code and signs in with it, once', async () => {
    const email = `sam-${crypto.randomUUID()}@example.com`;
    expect((await start(email)).status).toBe(200);
    await new Promise((r) => setTimeout(r, 10));
    const code = sentCode(email);
    const ok = await verify(email, code);
    expect(ok.status).toBe(200);
    const json = await ok.json<{ token: string; isNew: boolean; hasRecoveryKey: boolean }>();
    expect(json.token.length).toBeGreaterThan(40);
    expect(json.isNew).toBe(true);
    expect(json.hasRecoveryKey).toBe(false);
    // Only the token's hash is stored.
    const stored = await env.DB.prepare('SELECT token_hash FROM sessions WHERE token_hash = ?1').bind(json.token).first();
    expect(stored).toBeNull();
    // Replaying the code fails.
    expect((await verify(email, code)).status).toBe(400);
  });

  it('answers the same for any address (no enumeration) and stores only a hash', async () => {
    const email = `nobody-${crypto.randomUUID()}@example.com`;
    const response = await start(email);
    expect(await response.json()).toEqual({ ok: true });
    await new Promise((r) => setTimeout(r, 10));
    const row = await env.DB.prepare('SELECT code_hash FROM verification_codes WHERE email = ?1').bind(email).first<{ code_hash: string }>();
    expect(row?.code_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(row?.code_hash).not.toContain(sentCode(email));
  });

  it('allows 5 attempts, then the code is gone even if the 6th is right', async () => {
    const email = `try-${crypto.randomUUID()}@example.com`;
    await start(email);
    await new Promise((r) => setTimeout(r, 10));
    const code = sentCode(email);
    const wrong = code === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) expect((await verify(email, wrong)).status).toBe(400);
    expect((await verify(email, code)).status).toBe(400);
  });

  it('rejects an expired code', async () => {
    const email = `old-${crypto.randomUUID()}@example.com`;
    await start(email);
    await new Promise((r) => setTimeout(r, 10));
    await env.DB.prepare('UPDATE verification_codes SET expires_at = 0 WHERE email = ?1').bind(email).run();
    expect((await verify(email, sentCode(email))).status).toBe(400);
  });

  it('limits starts to 3 per address per 15 minutes, with Retry-After', async () => {
    const email = `busy-${crypto.randomUUID()}@example.com`;
    for (let i = 0; i < 3; i++) expect((await start(email, {}, `198.51.100.${i}`)).status).toBe(200);
    const limited = await start(email, {}, '198.51.100.9');
    expect(limited.status).toBe(429);
    expect(Number(limited.headers.get('retry-after'))).toBeGreaterThan(0);
  });

  it('limits starts to 10 per IP per hour', async () => {
    for (let i = 0; i < 10; i++) expect((await start(`ip-${i}-${crypto.randomUUID()}@example.com`, {}, '192.0.2.77')).status).toBe(200);
    expect((await start(`ip-x-${crypto.randomUUID()}@example.com`, {}, '192.0.2.77')).status).toBe(429);
  });

  it('needs Turnstile on the web', async () => {
    const response = await api('/auth/email/start', { method: 'POST', json: { email: 'web@example.com', client: 'web' }, headers: { origin: ORIGIN } });
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: 'turnstile' });
  });

  it('stays closed on the web while no Turnstile secret is set (Batch F)', async () => {
    const request = new Request(`${ORIGIN}/api/auth/email/start`, {
      method: 'POST', body: JSON.stringify({ email: 'web@example.com', client: 'web', turnstileToken: 'x' }),
      headers: { 'content-type': 'application/json', origin: ORIGIN },
    });
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, { ...env, TURNSTILE_SECRET: undefined }, ctx);
    await waitOnExecutionContext(ctx);
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: 'web_email_disabled' });
  });

  it('App Review address: fixed code from the secret, no email', async () => {
    OutboxSender.sent.delete('review@devilsense.com');
    expect((await start('Review@DevilSense.com')).status).toBe(200);
    await new Promise((r) => setTimeout(r, 10));
    expect(OutboxSender.sent.has('review@devilsense.com')).toBe(false);
    expect((await verify('review@devilsense.com', '424242')).status).toBe(200);
  });

  it('rejects malformed input', async () => {
    expect((await api('/auth/email/start', { method: 'POST', json: { email: 'not-an-email', client: 'ios' } })).status).toBe(400);
    expect((await api('/auth/email/verify', { method: 'POST', json: { email: 'a@b.co', code: '12', client: 'ios' } })).status).toBe(400);
    expect((await api('/auth/email/start', { method: 'POST', body: '{', headers: { 'content-type': 'application/json' } })).status).toBe(400);
  });

  it('links a second method with the same verified email to the same user', async () => {
    const email = `link-${crypto.randomUUID()}@example.com`;
    await start(email);
    await new Promise((r) => setTimeout(r, 10));
    const first = await (await verify(email, sentCode(email))).json<{ userId: string }>();
    const { resolveUser } = await import('../src/auth/users');
    const again = await resolveUser(env, { provider: 'google', providerUserId: 'g-123', email: email.toUpperCase(), emailVerified: true });
    expect(again).toEqual({ userId: first.userId, isNew: false });
  });
});
