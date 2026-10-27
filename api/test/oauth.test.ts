import { env } from 'cloudflare:test';
import { SignJWT, exportJWK, generateKeyPair } from 'jose';
import { beforeAll, describe, expect, it, vi } from 'vitest';
import { sha256Base64url, sha256Hex } from '../src/lib/crypto';
import { api, makeUser } from './helpers';

const { publicKey, privateKey } = await generateKeyPair('RS256');
const jwk = { ...(await exportJWK(publicKey)), kid: 'test', alg: 'RS256', use: 'sig' };

function idToken(issuer: string, audience: string, claims: Record<string, unknown>) {
  return new SignJWT(claims).setProtectedHeader({ alg: 'RS256', kid: 'test' }).setIssuer(issuer).setAudience(audience)
    .setIssuedAt().setExpirationTime('5m').sign(privateKey);
}

// Outbound calls to Apple and Google, answered locally; anything else fails the test.
const routes = new Map<string, () => unknown>([
  ['https://appleid.apple.com/auth/keys', () => ({ keys: [jwk] })],
  ['https://www.googleapis.com/oauth2/v3/certs', () => ({ keys: [jwk] })],
  ['https://appleid.apple.com/auth/token', () => ({ refresh_token: 'apple-refresh' })],
]);
let googleIdToken = '';
routes.set('https://oauth2.googleapis.com/token', () => ({ id_token: googleIdToken }));

beforeAll(() => {
  vi.stubGlobal('fetch', async (input: RequestInfo | URL) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    const route = routes.get(url.split('?')[0]!);
    if (!route) throw new Error(`unexpected fetch ${url}`);
    return Response.json(route());
  });
});

describe('Sign in with Apple, iOS (SPEC §10.2)', () => {
  const raw = 'a-raw-nonce-of-decent-length';

  it('verifies the identity token and nonce, and keeps the refresh token encrypted', async () => {
    const token = await idToken('https://appleid.apple.com', 'com.devilsense.folio', { sub: 'apple-1', email: 'x@privaterelay.appleid.com', email_verified: 'true', nonce: await sha256Hex(raw) });
    const response = await api('/auth/apple/native', { method: 'POST', json: { identityToken: token, rawNonce: raw, authorizationCode: 'c1', deviceName: 'iPhone' } });
    expect(response.status).toBe(200);
    const row = await env.DB.prepare(`SELECT refresh_token_enc FROM accounts WHERE provider = 'apple' AND provider_user_id = 'apple-1'`).first<{ refresh_token_enc: string }>();
    expect(row?.refresh_token_enc).toBeTruthy();
    expect(row?.refresh_token_enc).not.toContain('apple-refresh');
  });

  it('rejects a wrong nonce, a wrong audience and a forged signature', async () => {
    const wrongNonce = await idToken('https://appleid.apple.com', 'com.devilsense.folio', { sub: 'a2', nonce: await sha256Hex('other') });
    const wrongAud = await idToken('https://appleid.apple.com', 'com.evil.app', { sub: 'a2', nonce: await sha256Hex(raw) });
    const { privateKey: other } = await generateKeyPair('RS256');
    const forged = await new SignJWT({ sub: 'a2', nonce: await sha256Hex(raw) }).setProtectedHeader({ alg: 'RS256', kid: 'test' })
      .setIssuer('https://appleid.apple.com').setAudience('com.devilsense.folio').setExpirationTime('5m').sign(other);
    for (const token of [wrongNonce, wrongAud, forged]) {
      const response = await api('/auth/apple/native', { method: 'POST', json: { identityToken: token, rawNonce: raw, deviceName: 'iPhone' } });
      expect(response.status).toBe(401);
    }
  });

  it('re-authentication marks the current session instead of creating one', async () => {
    const first = await idToken('https://appleid.apple.com', 'com.devilsense.folio', { sub: 'apple-re', nonce: await sha256Hex(raw) });
    const signedIn = await (await api('/auth/apple/native', { method: 'POST', json: { identityToken: first, rawNonce: raw, deviceName: 'iPhone' } })).json<{ token: string }>();
    const again = await idToken('https://appleid.apple.com', 'com.devilsense.folio', { sub: 'apple-re', nonce: await sha256Hex(raw) });
    const response = await api('/auth/apple/native', { method: 'POST', token: signedIn.token, json: { identityToken: again, rawNonce: raw, deviceName: 'iPhone', reauth: true } });
    expect(await response.json()).toEqual({ reauthenticated: true });
    // Someone else's session can't be marked with my sign-in.
    const stranger = await makeUser();
    const mine = await idToken('https://appleid.apple.com', 'com.devilsense.folio', { sub: 'apple-re', nonce: await sha256Hex(raw) });
    const denied = await api('/auth/apple/native', { method: 'POST', token: stranger.token, json: { identityToken: mine, rawNonce: raw, deviceName: 'x', reauth: true } });
    expect(denied.status).toBe(403);
  });
});

describe('Google on iOS: one-time code handoff (SPEC §10.2)', () => {
  const verifier = 'v'.repeat(43);

  async function runFlow(sub: string) {
    const startResponse = await api(`/auth/google/start?platform=ios&challenge=${await sha256Base64url(verifier)}`);
    expect(startResponse.status).toBe(302);
    const location = new URL(startResponse.headers.get('location')!);
    expect(location.host).toBe('accounts.google.com');
    expect(location.searchParams.get('scope')).toBe('openid email profile');
    expect(location.searchParams.get('code_challenge_method')).toBe('S256');
    const state = location.searchParams.get('state')!;
    const nonce = location.searchParams.get('nonce')!;
    const token = await idToken('https://accounts.google.com', env.GOOGLE_CLIENT_ID, { sub, email: `${sub}@gmail.com`, email_verified: true, nonce });
    googleIdToken = token;
    const callback = await api(`/auth/callback/google?state=${state}&code=abc`);
    expect(callback.status).toBe(302);
    const appURL = new URL(callback.headers.get('location')!);
    expect(appURL.protocol).toBe('folio:');
    return { code: appURL.searchParams.get('code')!, state };
  }

  it('exchanges the code once, only with the app verifier', async () => {
    const { code, state } = await runFlow('g-1');
    expect((await api('/auth/exchange', { method: 'POST', json: { code, verifier: 'w'.repeat(43), deviceName: 'iPhone' } })).status).toBe(400);
    // A wrong verifier burns the code: a hijacking app gets nothing and the real one retries.
    const { code: code2 } = await runFlow('g-1');
    const ok = await api('/auth/exchange', { method: 'POST', json: { code: code2, verifier, deviceName: 'iPhone' } });
    expect(ok.status).toBe(200);
    expect((await ok.json<{ token: string }>()).token).toBeTruthy();
    expect((await api('/auth/exchange', { method: 'POST', json: { code: code2, verifier, deviceName: 'iPhone' } })).status).toBe(400);
    // The state can't be replayed either.
    expect((await api(`/auth/callback/google?state=${state}&code=abc`)).status).toBe(400);
  });

  it('an expired handoff code fails', async () => {
    const { code } = await runFlow('g-2');
    await env.DB.prepare('UPDATE handoff_codes SET expires_at = 0').run();
    expect((await api('/auth/exchange', { method: 'POST', json: { code, verifier, deviceName: 'iPhone' } })).status).toBe(400);
  });

  it('iOS start needs the app challenge; web callback needs the state cookie', async () => {
    expect((await api('/auth/google/start?platform=ios')).status).toBe(400);
    const web = await api('/auth/google/start?platform=web');
    expect(web.headers.get('set-cookie')).toContain('__Host-folio_oauth=');
    const state = new URL(web.headers.get('location')!).searchParams.get('state')!;
    expect((await api(`/auth/callback/google?state=${state}&code=abc`)).status).toBe(400);
  });
});
