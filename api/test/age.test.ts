// Accounts are 18+ (Batch L): a new account needs the sign-up screen's ticked box; existing
// accounts never see it; nothing single-use is spent when it's missing.
import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { resolveUser } from '../src/auth/users';
import { OutboxSender } from '../src/lib/email';
import { api } from './helpers';

const start = (email: string) => api('/auth/email/start', { method: 'POST', json: { email, client: 'ios' }, headers: { 'cf-connecting-ip': '203.0.113.40' } });
const verify = (email: string, code: string, extra: Record<string, unknown> = {}) =>
  api('/auth/email/verify', { method: 'POST', json: { email, code, client: 'ios', deviceName: 'iPhone', ...extra }, headers: { 'cf-connecting-ip': '203.0.113.41' } });
const codeFor = (email: string) => OutboxSender.sent.get(email)!.subject.match(/^(\d{6})/)![1]!;

describe('18+ accounts', () => {
  it('refuses a new account without the box, keeps the code, and records the confirmation once ticked', async () => {
    const email = `new-${crypto.randomUUID()}@example.com`;
    await start(email);
    await new Promise((r) => setTimeout(r, 10));
    const code = codeFor(email);
    const refused = await verify(email, code);
    expect(refused.status).toBe(403);
    expect((await refused.json<{ error: string }>()).error).toBe('age_required');
    expect(await env.DB.prepare('SELECT 1 FROM users WHERE email = ?1').bind(email).first()).toBeNull();
    const ok = await verify(email, code, { adult: true });
    expect(ok.status).toBe(200);
    const row = await env.DB.prepare('SELECT age_confirmed_at FROM users WHERE email = ?1').bind(email).first<{ age_confirmed_at: number }>();
    expect(row?.age_confirmed_at).toBeGreaterThan(Date.now() - 60_000);
  });

  it('an existing account signs in without it', async () => {
    const email = `old-${crypto.randomUUID()}@example.com`;
    await resolveUser(env, { provider: 'email', providerUserId: email, email, emailVerified: true }, null, Date.now(), true);
    await start(email);
    await new Promise((r) => setTimeout(r, 10));
    expect((await verify(email, codeFor(email))).status).toBe(200);
  });

  it('resolveUser never creates a user without it', async () => {
    const email = `direct-${crypto.randomUUID()}@example.com`;
    await expect(resolveUser(env, { provider: 'email', providerUserId: email, email, emailVerified: true })).rejects.toThrow();
  });

  it('the OAuth start remembers the box for the callback', async () => {
    const start1 = await api('/auth/google/start?platform=web&adult=1');
    expect(start1.status).toBe(302);
    const state = new URL(start1.headers.get('location')!).searchParams.get('state')!;
    const { results } = await env.DB.prepare('SELECT adult FROM oauth_states ORDER BY expires_at DESC LIMIT 1').all<{ adult: number }>();
    expect(state.startsWith('w.')).toBe(true);
    expect(results[0]?.adult).toBe(1);
  });
});
