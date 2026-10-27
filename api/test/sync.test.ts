import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { api, makeUser, record, secondSession } from './helpers';

interface PushResult { accepted: { id: string; version: number }[]; conflicts: { id: string; ciphertext: string; version: number; deleted: boolean }[]; cursor: number }
interface PullResult { changes: { id: string; version: number; ciphertext: string; deleted: boolean; type: string }[]; cursor: number; hasMore: boolean }

const push = (token: string, changes: unknown[]) => api('/sync/push', { method: 'POST', token, json: { changes } });
const pull = (token: string, since = 0, limit?: number) => api(`/sync/pull?since=${since}${limit ? `&limit=${limit}` : ''}`, { token });

describe('sync (SPEC §10.5)', () => {
  it('push assigns increasing versions; pull returns them after a cursor', async () => {
    const user = await makeUser();
    const a = record();
    const b = record();
    const result = await (await push(user.token, [a, b])).json<PushResult>();
    expect(result.accepted.map((x) => x.version)).toEqual([1, 2]);
    expect(result.cursor).toBe(2);
    const all = await (await pull(user.token)).json<PullResult>();
    expect(all.changes.map((c) => c.id)).toEqual([a.id, b.id]);
    const later = await (await pull(user.token, 1)).json<PullResult>();
    expect(later.changes.map((c) => c.id)).toEqual([b.id]);
    expect(later.cursor).toBe(2);
  });

  it('pages with hasMore', async () => {
    const user = await makeUser();
    await push(user.token, Array.from({ length: 5 }, () => record()));
    const page = await (await pull(user.token, 0, 2)).json<PullResult>();
    expect(page.changes).toHaveLength(2);
    expect(page.hasMore).toBe(true);
  });

  it('an update on the current version wins', async () => {
    const user = await makeUser();
    const first = record();
    const { accepted } = await (await push(user.token, [first])).json<PushResult>();
    const update = { ...first, ciphertext: btoa('v2'), baseVersion: accepted[0]!.version, clientUpdatedAt: first.clientUpdatedAt - 1000 };
    const result = await (await push(user.token, [update])).json<PushResult>();
    expect(result.accepted).toHaveLength(1);
    expect(result.conflicts).toHaveLength(0);
  });

  it('a conflict resolves last-writer-wins by clientUpdatedAt; the loser gets the server copy', async () => {
    const phone = await makeUser();
    const mac = await secondSession(phone);
    const base = record();
    const v1 = (await (await push(phone.token, [base])).json<PushResult>()).accepted[0]!.version;
    // Both edit from v1. The Mac's edit is newer.
    const fromMac = { ...base, ciphertext: btoa('mac'), baseVersion: v1, clientUpdatedAt: base.clientUpdatedAt + 2000 };
    const fromPhone = { ...base, ciphertext: btoa('phone'), baseVersion: v1, clientUpdatedAt: base.clientUpdatedAt + 1000 };
    expect((await (await push(mac.token, [fromMac])).json<PushResult>()).accepted).toHaveLength(1);
    const lost = await (await push(phone.token, [fromPhone])).json<PushResult>();
    expect(lost.accepted).toHaveLength(0);
    expect(lost.conflicts[0]!.ciphertext).toBe(btoa('mac'));
    // An even newer edit from the phone, still on the old base, wins.
    const newest = { ...base, ciphertext: btoa('phone2'), baseVersion: v1, clientUpdatedAt: base.clientUpdatedAt + 3000 };
    expect((await (await push(phone.token, [newest])).json<PushResult>()).accepted).toHaveLength(1);
  });

  it('trash and restore are ordinary updates; a tombstone is final', async () => {
    const user = await makeUser();
    const entry = record();
    let version = (await (await push(user.token, [entry])).json<PushResult>()).accepted[0]!.version;
    // "trashedAt" lives inside the ciphertext: to the server it's just another update.
    version = (await (await push(user.token, [{ ...entry, ciphertext: btoa('trashed'), baseVersion: version }])).json<PushResult>()).accepted[0]!.version;
    version = (await (await push(user.token, [{ ...entry, ciphertext: btoa('restored'), baseVersion: version }])).json<PushResult>()).accepted[0]!.version;
    const tomb = await (await push(user.token, [{ ...entry, ciphertext: '', deleted: true, baseVersion: version, clientUpdatedAt: Date.now() + 10 }])).json<PushResult>();
    expect(tomb.accepted).toHaveLength(1);
    const resurrect = await (await push(user.token, [{ ...entry, ciphertext: btoa('back'), baseVersion: null, clientUpdatedAt: Date.now() + 99_999 }])).json<PushResult>();
    expect(resurrect.accepted).toHaveLength(0);
    expect(resurrect.conflicts[0]!.deleted).toBe(true);
    const row = await env.DB.prepare('SELECT ciphertext, deleted FROM records WHERE id = ?1').bind(entry.id).first<{ ciphertext: string; deleted: number }>();
    expect(row).toEqual({ ciphertext: '', deleted: 1 });
  });

  it('users never see or overwrite each other\'s records', async () => {
    const alice = await makeUser();
    const bob = await makeUser();
    const secret = record();
    await push(alice.token, [secret]);
    expect((await (await pull(bob.token)).json<PullResult>()).changes).toHaveLength(0);
    // Bob pushing the same id creates his own record; Alice's is untouched.
    await push(bob.token, [{ ...secret, ciphertext: btoa('bob'), clientUpdatedAt: Date.now() + 50_000 }]);
    const alices = await (await pull(alice.token)).json<PullResult>();
    expect(alices.changes[0]!.ciphertext).toBe(secret.ciphertext);
  });

  it('rejects bad pushes: oversized, too many, duplicates, bad types', async () => {
    const user = await makeUser();
    const huge = await api('/sync/push', { method: 'POST', token: user.token, body: 'x'.repeat(1_100_000), headers: { 'content-type': 'application/json' } });
    expect(huge.status).toBe(413);
    expect((await push(user.token, Array.from({ length: 201 }, () => record()))).status).toBe(400);
    const one = record();
    expect((await push(user.token, [one, one])).status).toBe(400);
    expect((await push(user.token, [record(undefined, { type: 'secret' })])).status).toBe(400);
    expect((await push(user.token, [record('not-a-uuid')])).status).toBe(400);
    expect((await push(user.token, [])).status).toBe(400);
  });

  it('enforces the 50,000-record quota', async () => {
    const user = await makeUser();
    await env.DB.prepare('UPDATE users SET record_count = 49999 WHERE id = ?1').bind(user.userId).run();
    expect((await push(user.token, [record()])).status).toBe(200);
    const over = await push(user.token, [record()]);
    expect(over.status).toBe(413);
    expect(await over.json()).toEqual({ error: 'quota_records' });
  });

  it('stores only ciphertext and the minimal metadata', async () => {
    const user = await makeUser();
    const entry = record();
    await push(user.token, [entry]);
    const columns = await env.DB.prepare('SELECT * FROM records WHERE id = ?1').bind(entry.id).first<Record<string, unknown>>();
    expect(Object.keys(columns!).sort()).toEqual(['ciphertext', 'client_updated_at', 'deleted', 'id', 'nonce', 'size', 'type', 'user_id', 'version']);
  });
});
