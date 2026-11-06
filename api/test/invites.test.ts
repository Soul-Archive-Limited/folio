// Invite-only sign-up (Batch J).
import { createExecutionContext, env, waitOnExecutionContext } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import worker from '../src/index';
import { OutboxSender } from '../src/lib/email';
import { normaliseInvite } from '../src/lib/invites';
import { api, makeUser, ORIGIN } from './helpers';

const gated = { ...env, INVITES_REQUIRED: 'true' };

async function call(path: string, json: unknown, extra: Record<string, string> = {}, bindings: object = gated) {
  const request = new Request(`${ORIGIN}/api${path}`, {
    method: 'POST', body: JSON.stringify(json),
    headers: { 'content-type': 'application/json', 'cf-connecting-ip': `198.51.100.${Math.floor(Math.random() * 250)}`, ...extra },
  });
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, bindings as typeof env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

async function emailCode(email: string): Promise<string> {
  expect((await call('/auth/email/start', { email, client: 'ios' })).status).toBe(200);
  const code = OutboxSender.sent.get(email)?.subject.match(/^(\d{6})/)?.[1];
  if (!code) throw new Error('no code');
  return code;
}

const verify = (email: string, code: string, invite?: string) =>
  call('/auth/email/verify', { email, code, client: 'ios', deviceName: 'iPhone', adult: true, ...(invite ? { invite } : {}) });

let owner: ReturnType<typeof makeUser> | undefined;

async function ownerInvite(): Promise<{ code: string; id: string; token: string }> {
  owner ??= makeUser('owner@example.com');
  const { token } = await owner;
  const made = await api('/invites', { method: 'POST', token });
  expect(made.status).toBe(200);
  const { code, id } = await made.json<{ code: string; id: string }>();
  return { code, id, token };
}

describe('invite-only sign-up', () => {
  it('codes look like ABCD-EFGH and normalise what people type', () => {
    expect(normaliseInvite('abcd-efgh')).toBe('ABCDEFGH');
    expect(normaliseInvite(' k7qm 4xt2 ')).toBe('K7QM4XT2');
    expect(normaliseInvite('O0IL-1234')).toBe('00111234');
    expect(normaliseInvite('ABCD-EFG')).toBeNull();
    expect(normaliseInvite('ABCD-EFGU')).toBeNull();
  });

  it('a new email account needs an invite; the code stays valid while the app asks for one', async () => {
    const email = `new-${crypto.randomUUID()}@example.com`;
    const code = await emailCode(email);
    const refused = await verify(email, code);
    expect(refused.status).toBe(403);
    expect(await refused.json()).toEqual({ error: 'invite_required' });
    expect(await (await verify(email, code, 'ZZZZ-ZZZZ')).json()).toEqual({ error: 'invite_invalid' });

    const { code: invite } = await ownerInvite();
    const ok = await verify(email, code, invite.toLowerCase());
    expect(ok.status).toBe(200);
    expect((await ok.json<{ isNew: boolean }>()).isNew).toBe(true);
  });

  it('an invite works once', async () => {
    const { code: invite } = await ownerInvite();
    const first = `a-${crypto.randomUUID()}@example.com`;
    expect((await verify(first, await emailCode(first), invite)).status).toBe(200);
    const second = `b-${crypto.randomUUID()}@example.com`;
    expect(await (await verify(second, await emailCode(second), invite)).json()).toEqual({ error: 'invite_invalid' });
  });

  it('existing accounts, the owner and App Review sign in without one', async () => {
    const existing = `old-${crypto.randomUUID()}@example.com`;
    await makeUser(existing);
    expect((await verify(existing, await emailCode(existing))).status).toBe(200);
    expect((await verify('second-owner@example.com', await emailCode('second-owner@example.com'))).status).toBe(200);
    const review = await call('/auth/email/start', { email: env.REVIEW_EMAIL, client: 'ios' });
    expect(review.status).toBe(200);
    expect((await verify(env.REVIEW_EMAIL, env.REVIEW_CODE!)).status).toBe(200);
  });

  it('expired and revoked invites are refused', async () => {
    const { code, id, token } = await ownerInvite();
    expect((await api(`/invites/${id}`, { method: 'DELETE', token })).status).toBe(200);
    const email = `c-${crypto.randomUUID()}@example.com`;
    expect(await (await verify(email, await emailCode(email), code)).json()).toEqual({ error: 'invite_invalid' });

    const second = await api('/invites', { method: 'POST', token });
    const fresh = await second.json<{ code: string; id: string }>();
    await env.DB.prepare('UPDATE invites SET expires_at = 1 WHERE id = ?1').bind(fresh.id).run();
    const other = `d-${crypto.randomUUID()}@example.com`;
    expect(await (await verify(other, await emailCode(other), fresh.code)).json()).toEqual({ error: 'invite_invalid' });
  });

  it('only owners make and see invites; codes are stored hashed; used ones cannot be revoked', async () => {
    const stranger = await makeUser();
    expect((await api('/invites', { method: 'POST', token: stranger.token })).status).toBe(403);
    expect((await api('/invites', { token: stranger.token })).status).toBe(403);
    const { code, id, token } = await ownerInvite();
    const row = await env.DB.prepare('SELECT code_hash, hint FROM invites WHERE id = ?1').bind(id).first<{ code_hash: string; hint: string }>();
    expect(row?.code_hash).not.toContain(normaliseInvite(code)!);
    expect(row?.hint).toBe(code.slice(-2));
    const me = await api('/account/me', { token });
    expect((await me.json<{ canInvite: boolean }>()).canInvite).toBe(true);
    const list = await (await api('/invites', { token })).json<{ invites: { id: string; status: string }[] }>();
    expect(list.invites.find((i) => i.id === id)?.status).toBe('open');

    const email = `e-${crypto.randomUUID()}@example.com`;
    expect((await verify(email, await emailCode(email), code)).status).toBe(200);
    expect((await api(`/invites/${id}`, { method: 'DELETE', token })).status).toBe(404);
    const after = await (await api('/invites', { token })).json<{ invites: { id: string; status: string }[] }>();
    expect(after.invites.find((i) => i.id === id)?.status).toBe('used');
  });

  it('with invites switched off, anyone can sign up (the existing behaviour)', async () => {
    const email = `f-${crypto.randomUUID()}@example.com`;
    const code = await emailCode(email);
    expect((await call('/auth/email/verify', { email, code, client: 'ios', deviceName: 'iPhone', adult: true }, {}, { ...env, INVITES_REQUIRED: 'false' })).status).toBe(200);
  });
});
