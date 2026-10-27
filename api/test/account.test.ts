import { env, runDurableObjectAlarm, SELF } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { OutboxSender } from '../src/lib/email';
import { api, makeUser, ORIGIN, record, secondSession } from './helpers';

/** Runs any pending wipe step, then waits for one already running (alarms also fire on their own). */
async function finishWipe(userId: string) {
  const hub = env.USER_HUB.get(env.USER_HUB.idFromName(userId));
  for (let i = 0; i < 100; i++) {
    await runDurableObjectAlarm(hub);
    const left = await env.DB.prepare('SELECT COUNT(*) AS n FROM accounts WHERE user_id = ?1').bind(userId).first<{ n: number }>();
    if (left?.n === 0) return;
    await new Promise((r) => setTimeout(r, 20));
  }
  throw new Error('wipe did not finish');
}

describe('delete account (SPEC §10.6)', () => {
  async function seeded() {
    const email = `gone-${crypto.randomUUID()}@example.com`;
    const user = await makeUser(email);
    await api('/sync/push', { method: 'POST', token: user.token, json: { changes: [record(), record()] } });
    const blob = `${crypto.randomUUID()}.full`;
    await api(`/blobs/${blob}`, { method: 'PUT', token: user.token, body: new Uint8Array(100), headers: { 'content-length': '100' } });
    await api('/keys/recovery', { method: 'PUT', token: user.token, json: { envelope: btoa('wrapped') } });
    return { user, email };
  }

  it('needs DELETE and a recent sign-in', async () => {
    const { user } = await seeded();
    expect((await api('/account/delete', { method: 'POST', token: user.token, json: { confirm: 'delete' } })).status).toBe(400);
    await env.DB.prepare('UPDATE sessions SET reauth_at = ?2 WHERE id = ?1').bind(user.sessionId, Date.now() - 11 * 60_000).run();
    expect((await api('/account/delete', { method: 'POST', token: user.token, json: { confirm: 'DELETE' } })).status).toBe(403);
  });

  it('wipes D1 and R2, logs only a hash, emails a confirmation', async () => {
    const { user, email } = await seeded();
    const other = await secondSession(user);
    const keep = await makeUser();
    await api('/sync/push', { method: 'POST', token: keep.token, json: { changes: [record()] } });

    expect((await api('/account/delete', { method: 'POST', token: user.token, json: { confirm: 'DELETE' } })).status).toBe(200);
    // Every session stops at once, before the wipe finishes.
    expect((await api('/account/me', { token: other.token })).status).toBe(401);

    await finishWipe(user.userId);

    for (const table of ['records', 'blobs', 'key_envelopes', 'sessions', 'accounts', 'link_requests']) {
      const row = await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE user_id = ?1`).bind(user.userId).first<{ n: number }>();
      expect(row?.n, table).toBe(0);
    }
    expect(await env.DB.prepare('SELECT id FROM users WHERE id = ?1').bind(user.userId).first()).toBeNull();
    expect((await env.BLOBS.list({ prefix: `u/${user.userId}/` })).objects).toHaveLength(0);
    const log = await env.DB.prepare('SELECT id_hash FROM deletions_log ORDER BY deleted_at DESC LIMIT 1').first<{ id_hash: string }>();
    expect(log?.id_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(log?.id_hash).not.toContain(user.userId);
    expect(OutboxSender.sent.get(email)?.subject).toBe('Your Folio account was deleted');
    // Someone else's diary is untouched.
    expect((await (await api('/sync/pull', { token: keep.token })).json<{ changes: unknown[] }>()).changes).toHaveLength(1);
  });

  it('is limited to 3 attempts a day', async () => {
    const user = await makeUser();
    for (let i = 0; i < 3; i++) await api('/account/delete', { method: 'POST', token: user.token, json: { confirm: 'nope' } });
    expect((await api('/account/delete', { method: 'POST', token: user.token, json: { confirm: 'DELETE' } })).status).toBe(429);
  });
});

describe('live socket (SPEC §10.5)', () => {
  it('needs a session and an upgrade', async () => {
    expect((await api('/live', { headers: { upgrade: 'websocket' } })).status).toBe(401);
    const user = await makeUser();
    expect((await api('/live', { token: user.token })).status).toBe(426);
  });

  it('tells the user\'s other devices to pull after a push, and answers pings', async () => {
    const phone = await makeUser();
    const mac = await secondSession(phone);
    const response = await SELF.fetch(`${ORIGIN}/api/live`, { headers: { upgrade: 'websocket', authorization: `Bearer ${mac.token}` } });
    expect(response.status).toBe(101);
    const socket = response.webSocket!;
    socket.accept();
    const messages: string[] = [];
    socket.addEventListener('message', (event) => { messages.push(String(event.data)); });
    socket.send('ping');
    await api('/sync/push', { method: 'POST', token: phone.token, json: { changes: [record()] } });
    for (let i = 0; i < 50 && messages.length < 3; i++) await new Promise((r) => setTimeout(r, 20));
    expect(messages[0]).toBe(JSON.stringify({ cursor: 0 }));   // the cursor on connect
    expect(messages).toContain('pong');
    expect(messages).toContain(JSON.stringify({ cursor: 1 }));
    socket.close();
  });
});

describe('admin usage (SPEC §15.2)', () => {
  it('is closed without a Cloudflare Access token', async () => {
    expect((await api('/admin/usage')).status).toBe(403);
    expect((await api('/admin/usage', { headers: { 'cf-access-jwt-assertion': 'forged.jwt.token' } })).status).toBe(403);
  });
});

describe('signing in during a deletion', () => {
  it('answers 409 until the wipe finishes, then starts fresh', async () => {
    const { resolveUser } = await import('../src/auth/users');
    const email = `again-${crypto.randomUUID()}@example.com`;
    const user = await makeUser(email);
    expect((await api('/account/delete', { method: 'POST', token: user.token, json: { confirm: 'DELETE' } })).status).toBe(200);
    await expect(resolveUser(env, { provider: 'email', providerUserId: email, email, emailVerified: true })).rejects.toThrow();
    await finishWipe(user.userId);
    const fresh = await resolveUser(env, { provider: 'email', providerUserId: email, email, emailVerified: true });
    expect(fresh.isNew).toBe(true);
    expect(fresh.userId).not.toBe(user.userId);
  });
});
