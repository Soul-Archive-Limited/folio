import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { api, makeUser, secondSession } from './helpers';

const blobId = () => `${crypto.randomUUID()}.thumb`;
const put = (token: string, id: string, bytes: Uint8Array, headers: Record<string, string> = {}) =>
  api(`/blobs/${id}`, { method: 'PUT', token, body: bytes, headers: { 'content-length': String(bytes.byteLength), ...headers } });

describe('blobs (SPEC §10.5)', () => {
  it('stores, streams back and deletes an encrypted rendition under u/<user>/', async () => {
    const user = await makeUser();
    const id = blobId();
    const bytes = crypto.getRandomValues(new Uint8Array(5000));
    expect((await put(user.token, id, bytes)).status).toBe(200);
    expect(await env.BLOBS.head(`u/${user.userId}/${id}`)).not.toBeNull();
    const got = await api(`/blobs/${id}`, { token: user.token });
    expect(got.headers.get('cache-control')).toBe('private, max-age=31536000, immutable');
    expect(new Uint8Array(await got.arrayBuffer())).toEqual(bytes);
    const usage = await env.DB.prepare('SELECT blob_bytes FROM users WHERE id = ?1').bind(user.userId).first<{ blob_bytes: number }>();
    expect(usage?.blob_bytes).toBe(5000);
    expect((await api(`/blobs/${id}`, { method: 'DELETE', token: user.token })).status).toBe(200);
    expect((await api(`/blobs/${id}`, { token: user.token })).status).toBe(404);
  });

  it('another user can\'t read or delete it', async () => {
    const alice = await makeUser();
    const bob = await makeUser();
    const id = blobId();
    await put(alice.token, id, new Uint8Array(10));
    expect((await api(`/blobs/${id}`, { token: bob.token })).status).toBe(404);
    await api(`/blobs/${id}`, { method: 'DELETE', token: bob.token });
    expect((await api(`/blobs/${id}`, { token: alice.token })).status).toBe(200);
  });

  it('rejects oversized, unsized and badly named uploads, and enforces 1 GB', async () => {
    const user = await makeUser();
    const big = await api(`/blobs/${blobId()}`, { method: 'PUT', token: user.token, body: new Uint8Array(10), headers: { 'content-length': String(5 * 1024 * 1024) } });
    expect(big.status).toBe(413);
    expect((await put(user.token, '../../etc/passwd', new Uint8Array(10))).status).toBe(404);
    expect((await put(user.token, 'abc.thumb', new Uint8Array(10))).status).toBe(400);
    await env.DB.prepare('UPDATE users SET blob_bytes = ?2 WHERE id = ?1').bind(user.userId, 1024 * 1024 * 1024 - 5).run();
    expect((await put(user.token, blobId(), new Uint8Array(10))).status).toBe(413);
  });

  it('limits uploads to 60 per hour', async () => {
    const user = await makeUser();
    for (let i = 0; i < 60; i++) expect((await put(user.token, blobId(), new Uint8Array(1))).status).toBe(200);
    expect((await put(user.token, blobId(), new Uint8Array(1))).status).toBe(429);
  });
});

describe('recovery envelope (SPEC §10.4)', () => {
  it('is set once, read back, and replaced only after re-authentication', async () => {
    const user = await makeUser();
    expect((await api('/keys/recovery', { token: user.token })).status).toBe(404);
    expect((await api('/keys/recovery', { method: 'PUT', token: user.token, json: { envelope: btoa('wrapped-1') } })).status).toBe(200);
    expect((await api('/keys/recovery', { method: 'PUT', token: user.token, json: { envelope: btoa('wrapped-2') } })).status).toBe(409);
    expect((await (await api('/keys/recovery', { token: user.token })).json<{ envelope: string }>()).envelope).toBe(btoa('wrapped-1'));
    await env.DB.prepare('UPDATE sessions SET reauth_at = 0 WHERE id = ?1').bind(user.sessionId).run();
    expect((await api('/keys/recovery', { method: 'PUT', token: user.token, json: { envelope: btoa('wrapped-2'), replace: true } })).status).toBe(403);
  });
});

describe('device linking (SPEC §10.4)', () => {
  const key = () => btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))));

  it('relays the encrypted key once, between devices of the same account', async () => {
    const phone = await makeUser();
    const browser = await secondSession(phone, 'Chrome on Mac');
    const created = await (await api('/link', { method: 'POST', token: browser.token, json: { publicKey: key() } })).json<{ id: string }>();
    const seen = await (await api(`/link/${created.id}`, { token: phone.token })).json<{ deviceName: string }>();
    expect(seen.deviceName).toBe('Chrome on Mac');
    expect((await (await api(`/link/${created.id}`, { token: browser.token })).json<{ status: string }>()).status).toBe('waiting');
    expect((await api(`/link/${created.id}/approve`, { method: 'POST', token: browser.token, json: { senderPublicKey: key(), envelope: btoa('x'), nonce: btoa('n') } })).status).toBe(403);
    const approval = { senderPublicKey: key(), envelope: btoa('dk-encrypted'), nonce: btoa('123456789012') };
    expect((await api(`/link/${created.id}/approve`, { method: 'POST', token: phone.token, json: approval })).status).toBe(200);
    const got = await (await api(`/link/${created.id}`, { token: browser.token })).json<{ status: string; envelope: string }>();
    expect(got).toMatchObject({ status: 'approved', envelope: approval.envelope });
    expect((await api(`/link/${created.id}`, { token: browser.token })).status).toBe(404);
  });

  it('another account can\'t see or approve it; it expires after 5 minutes', async () => {
    const user = await makeUser();
    const stranger = await makeUser();
    const { id } = await (await api('/link', { method: 'POST', token: user.token, json: { publicKey: key() } })).json<{ id: string }>();
    expect((await api(`/link/${id}`, { token: stranger.token })).status).toBe(404);
    expect((await api(`/link/${id}/approve`, { method: 'POST', token: stranger.token, json: { senderPublicKey: key(), envelope: btoa('x'), nonce: btoa('n') } })).status).toBe(404);
    await env.DB.prepare('UPDATE link_requests SET expires_at = 0 WHERE id = ?1').bind(id).run();
    expect((await api(`/link/${id}`, { token: user.token })).status).toBe(410);
  });

  it('limits link requests to 10 per hour and rejects bad keys', async () => {
    const user = await makeUser();
    expect((await api('/link', { method: 'POST', token: user.token, json: { publicKey: 'short' } })).status).toBe(400);
    for (let i = 0; i < 9; i++) await api('/link', { method: 'POST', token: user.token, json: { publicKey: key() } });
    expect((await api('/link', { method: 'POST', token: user.token, json: { publicKey: key() } })).status).toBe(429);
  });
});
