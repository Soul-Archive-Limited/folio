import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { PHOTO_PUTS_PER_HOUR } from '../src/routes/blobs';
import { api, makeUser, secondSession } from './helpers';

/** Three big-endian uint32 lengths, then the three sealed renditions. */
function photoBody(thumb: number, display: number, full: number): Uint8Array {
  const out = new Uint8Array(12 + thumb + display + full);
  const view = new DataView(out.buffer);
  view.setUint32(0, thumb);
  view.setUint32(4, display);
  view.setUint32(8, full);
  out.fill(1, 12, 12 + thumb);
  out.fill(2, 12 + thumb, 12 + thumb + display);
  out.fill(3, 12 + thumb + display);
  return out;
}

const putPhoto = (token: string, id: string, bytes: Uint8Array) =>
  api(`/blobs/photo/${id}`, { method: 'PUT', token, body: bytes, headers: { 'content-length': String(bytes.byteLength) } });

describe('one request per photo (Batch F)', () => {
  it('stores the three renditions as the usual three blobs', async () => {
    const user = await makeUser();
    const id = crypto.randomUUID();
    expect((await putPhoto(user.token, id, photoBody(10, 20, 30))).status).toBe(200);
    for (const [rendition, size, fill] of [['thumb', 10, 1], ['display', 20, 2], ['full', 30, 3]] as const) {
      const got = await api(`/blobs/${id}.${rendition}`, { token: user.token });
      const bytes = new Uint8Array(await got.arrayBuffer());
      expect(bytes.byteLength).toBe(size);
      expect(bytes.every((b) => b === fill)).toBe(true);
    }
    const usage = await env.DB.prepare('SELECT blob_bytes FROM users WHERE id = ?1').bind(user.userId).first<{ blob_bytes: number }>();
    expect(usage?.blob_bytes).toBe(60);
    // Uploading again replaces, it doesn't double count.
    expect((await putPhoto(user.token, id, photoBody(10, 20, 30))).status).toBe(200);
    const again = await env.DB.prepare('SELECT blob_bytes FROM users WHERE id = ?1').bind(user.userId).first<{ blob_bytes: number }>();
    expect(again?.blob_bytes).toBe(60);
  });

  it('rejects lengths that don\'t add up, empty parts, bad ids and the 1 GB quota', async () => {
    const user = await makeUser();
    const good = photoBody(5, 5, 5);
    const lying = good.slice();
    new DataView(lying.buffer).setUint32(8, 6);
    expect((await putPhoto(user.token, crypto.randomUUID(), lying)).status).toBe(400);
    expect((await putPhoto(user.token, crypto.randomUUID(), photoBody(0, 5, 5))).status).toBe(400);
    expect((await putPhoto(user.token, 'not-a-uuid', good)).status).toBe(400);
    await env.DB.prepare('UPDATE users SET blob_bytes = ?2 WHERE id = ?1').bind(user.userId, 1024 * 1024 * 1024 - 5).run();
    expect((await putPhoto(user.token, crypto.randomUUID(), good)).status).toBe(413);
  });

  it(`allows ${PHOTO_PUTS_PER_HOUR} photos an hour`, async () => {
    const user = await makeUser();
    await env.DB.prepare('INSERT INTO rate_limits (key, window_start, count) VALUES (?1, ?2, ?3)')
      .bind(`photo-put:${user.userId}`, Math.floor(Date.now() / 3_600_000) * 3600, PHOTO_PUTS_PER_HOUR - 1).run();
    expect((await putPhoto(user.token, crypto.randomUUID(), photoBody(1, 1, 1))).status).toBe(200);
    const limited = await putPhoto(user.token, crypto.randomUUID(), photoBody(1, 1, 1));
    expect(limited.status).toBe(429);
    expect(Number(limited.headers.get('retry-after'))).toBeGreaterThan(0);
  });
});

describe('device names (Batch F)', () => {
  it('updates this device\'s model and OS, and stores a sealed label for any of the person\'s devices', async () => {
    const user = await makeUser();
    const mac = await secondSession(user, 'Chrome on macOS');
    expect((await api('/account/device', { method: 'PUT', token: user.token, json: { name: 'iPhone 15 Pro · iOS 27.1' } })).status).toBe(200);
    const label = { ciphertext: btoa('sealed-name-bytes'), nonce: btoa('twelve bytes') };
    expect((await api(`/account/devices/${mac.sessionId}/label`, { method: 'PUT', token: user.token, json: { label } })).status).toBe(200);

    const list = await (await api('/account/devices', { token: user.token })).json() as { devices: { id: string; name: string; current: boolean; createdAt: number; label: unknown }[] };
    const phone = list.devices.find((d) => d.id === user.sessionId)!;
    const browser = list.devices.find((d) => d.id === mac.sessionId)!;
    expect(phone).toMatchObject({ name: 'iPhone 15 Pro · iOS 27.1', current: true, label: null });
    expect(browser).toMatchObject({ name: 'Chrome on macOS', current: false, label });
    expect(browser.createdAt).toBeGreaterThan(0);

    expect((await api(`/account/devices/${mac.sessionId}/label`, { method: 'PUT', token: user.token, json: { label: null } })).status).toBe(200);
    const cleared = await (await api('/account/devices', { token: mac.token })).json() as { devices: { id: string; label: unknown; current: boolean }[] };
    expect(cleared.devices.find((d) => d.id === mac.sessionId)).toMatchObject({ label: null, current: true });
  });

  it('can\'t label another account\'s device, and checks the label\'s shape', async () => {
    const alice = await makeUser();
    const bob = await makeUser();
    const label = { ciphertext: btoa('x'), nonce: btoa('twelve bytes') };
    expect((await api(`/account/devices/${alice.sessionId}/label`, { method: 'PUT', token: bob.token, json: { label } })).status).toBe(404);
    expect((await api(`/account/devices/${alice.sessionId}/label`, { method: 'PUT', token: alice.token, json: { label: { ciphertext: 'x'.repeat(500), nonce: label.nonce } } })).status).toBe(400);
    expect((await api('/account/device', { method: 'PUT', token: alice.token, json: { name: '' } })).status).toBe(400);
  });
});

describe('web re-authentication with Apple (Batch F, DECISIONS 194)', () => {
  it('marks the session that asked, although Apple\'s POST carries no session cookie', async () => {
    const { SignJWT, generateKeyPair, exportJWK } = await import('jose');
    const { vi } = await import('vitest');
    const { publicKey, privateKey } = await generateKeyPair('RS256');
    const jwk = { ...(await exportJWK(publicKey)), kid: 'web', alg: 'RS256', use: 'sig' };
    let idToken = '';
    vi.stubGlobal('fetch', async (input: RequestInfo | URL) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
      if (url.startsWith('https://appleid.apple.com/auth/keys')) return Response.json({ keys: [jwk] });
      if (url.startsWith('https://appleid.apple.com/auth/token')) return Response.json({ id_token: idToken });
      throw new Error(`unexpected fetch ${url}`);
    });
    const user = await makeUser();
    const web = await secondSession(user, 'Brave on macOS');
    await env.DB.prepare(`INSERT INTO accounts (id, user_id, provider, provider_user_id, created_at) VALUES (?1, ?2, 'apple', 'apple-web-1', ?3)`)
      .bind(crypto.randomUUID(), user.userId, Date.now()).run();
    await env.DB.prepare('UPDATE sessions SET reauth_at = 0 WHERE id = ?1').bind(web.sessionId).run();

    const start = await api('/auth/apple/start?reauth=1', { headers: { cookie: `__Host-folio_session=${web.token}` } });
    expect(start.status).toBe(302);
    const authorize = new URL(start.headers.get('location')!);
    const state = authorize.searchParams.get('state')!;
    const nonce = authorize.searchParams.get('nonce')!;
    idToken = await new SignJWT({ sub: 'apple-web-1', nonce }).setProtectedHeader({ alg: 'RS256', kid: 'web' })
      .setIssuer('https://appleid.apple.com').setAudience('com.devilsense.folio.web').setIssuedAt().setExpirationTime('5m').sign(privateKey);

    const callback = await api('/auth/callback/apple', {
      method: 'POST', body: new URLSearchParams({ state, code: 'web-code' }),
      headers: { cookie: `__Host-folio_oauth=${state}`, 'content-type': 'application/x-www-form-urlencoded', origin: 'https://appleid.apple.com' },
    });
    expect(callback.status).toBe(303);
    expect(callback.headers.get('location')).toBe('/app/settings/account?reauth=1');
    const row = await env.DB.prepare('SELECT reauth_at FROM sessions WHERE id = ?1').bind(web.sessionId).first<{ reauth_at: number }>();
    expect(row!.reauth_at).toBeGreaterThan(0);
    vi.unstubAllGlobals();
  });

  it('needs a signed-in browser to start', async () => {
    expect((await api('/auth/apple/start?reauth=1')).status).toBe(401);
  });
});

describe('GET /api/auth/session', () => {
  it('answers 200 either way', async () => {
    const user = await makeUser();
    expect(await (await api('/auth/session')).json()).toEqual({ signedIn: false });
    expect(await (await api('/auth/session', { token: user.token })).json()).toEqual({ signedIn: true });
  });
});
