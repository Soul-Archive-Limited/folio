// Batch L security audit: every route that takes an id or reads account data is scoped to the
// session's user. Alice's things are invisible and untouchable for Bob (IDOR).
import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { api, makeUser, record, secondSession } from './helpers';

const key = () => btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))));

describe('authorization is per user (IDOR)', () => {
  it('records: pull never returns another user\'s records; the same id under another user is a different record', async () => {
    const alice = await makeUser();
    const bob = await makeUser();
    const shared = record();
    expect((await api('/sync/push', { method: 'POST', token: alice.token, json: { changes: [shared] } })).status).toBe(200);
    const bobPull = await (await api('/sync/pull?since=0', { token: bob.token })).json<{ changes: { id: string }[] }>();
    expect(bobPull.changes.map((c) => c.id)).not.toContain(shared.id);
    // Bob writes the same id: it lands in Bob's space; Alice's ciphertext is untouched.
    const forged = { ...shared, ciphertext: btoa('bob'), baseVersion: null };
    expect((await api('/sync/push', { method: 'POST', token: bob.token, json: { changes: [forged] } })).status).toBe(200);
    const aliceRow = await env.DB.prepare('SELECT ciphertext FROM records WHERE user_id = ?1 AND id = ?2').bind(alice.userId, shared.id).first<{ ciphertext: string }>();
    expect(aliceRow?.ciphertext).toBe(shared.ciphertext);
    // A delete tombstone from Bob doesn't delete Alice's record either.
    await api('/sync/push', { method: 'POST', token: bob.token, json: { changes: [{ ...shared, deleted: true, ciphertext: '', baseVersion: null }] } });
    const still = await env.DB.prepare('SELECT deleted FROM records WHERE user_id = ?1 AND id = ?2').bind(alice.userId, shared.id).first<{ deleted: number }>();
    expect(still?.deleted).toBe(0);
  });

  it('devices: Bob can\'t rename or sign out Alice\'s sessions, and doesn\'t see them', async () => {
    const alice = await makeUser();
    const aliceWeb = await secondSession(alice);
    const bob = await makeUser();
    expect((await api(`/account/devices/${aliceWeb.sessionId}`, { method: 'DELETE', token: bob.token })).status).toBe(404);
    expect((await api(`/account/devices/${aliceWeb.sessionId}/label`, { method: 'PUT', token: bob.token, json: { label: { ciphertext: btoa('x'), nonce: btoa('1234567890123456') } } })).status).toBe(404);
    const devices = await (await api('/account/devices', { token: bob.token })).json<{ devices: { id: string }[] }>();
    expect(devices.devices.map((d) => d.id)).not.toContain(aliceWeb.sessionId);
    expect((await api('/account/me', { token: aliceWeb.token })).status).toBe(200);
  });

  it('device linking: another account can\'t read, approve or cancel a link request', async () => {
    const alice = await makeUser();
    const aliceWeb = await secondSession(alice, 'Safari on macOS');
    const bob = await makeUser();
    const created = await (await api('/link', { method: 'POST', token: aliceWeb.token, json: { publicKey: key() } })).json<{ id: string }>();
    expect((await api(`/link/${created.id}`, { token: bob.token })).status).toBe(404);
    expect((await api(`/link/${created.id}/approve`, { method: 'POST', token: bob.token, json: { senderPublicKey: key(), envelope: btoa('stolen?'), nonce: btoa('123456789012') } })).status).toBe(404);
    // Cancel is idempotent (always 200) but scoped to the owner: Alice's request is still there.
    await api(`/link/${created.id}`, { method: 'DELETE', token: bob.token });
    expect((await (await api(`/link/${created.id}`, { token: aliceWeb.token })).json<{ status: string }>()).status).toBe('waiting');
  });

  it('recovery envelope: each user sees only their own', async () => {
    const alice = await makeUser();
    const bob = await makeUser();
    await api('/keys/recovery', { method: 'PUT', token: alice.token, json: { envelope: btoa('alice-wrapped') } });
    expect((await api('/keys/recovery', { token: bob.token })).status).toBe(404);
  });

  it('a session token from one user never authenticates as another, and a bad token is refused', async () => {
    const alice = await makeUser();
    const me = await (await api('/account/me', { token: alice.token })).json<{ userId: string }>();
    expect(me.userId).toBe(alice.userId);
    expect((await api('/account/me', { token: 'x'.repeat(43) })).status).toBe(401);
  });

  it('errors don\'t leak internals', async () => {
    const alice = await makeUser();
    const bad = await api('/sync/push', { method: 'POST', token: alice.token, json: { changes: [{ id: 'not-a-uuid', type: 'entry' }] } });
    expect(bad.status).toBe(400);
    const text = await bad.text();
    expect(text).toBe('{"error":"invalid_request"}');
    const missing = await api('/no/such/route', { token: alice.token });
    expect(missing.status).toBe(404);
    expect(await missing.text()).not.toMatch(/stack|at |Error:|D1|sqlite/i);
  });
});
