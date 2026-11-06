import { env } from 'cloudflare:test';
import { SignJWT, exportJWK, generateKeyPair } from 'jose';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { exchangeGoogleCode } from '../src/auth/google';
import { sha256Base64url, sha256Hex } from '../src/lib/crypto';
import { api, makeUser } from './helpers';

const { publicKey, privateKey } = await generateKeyPair('RS256');
const jwk = { ...(await exportJWK(publicKey)), kid: 'test', alg: 'RS256', use: 'sig' };

function idToken(issuer: string, audience: string, claims: Record<string, unknown>) {
  return new SignJWT(claims).setProtectedHeader({ alg: 'RS256', kid: 'test' }).setIssuer(issuer).setAudience(audience)
    .setIssuedAt().setExpirationTime('5m').sign(privateKey);
}

// Outbound calls to Apple and Google, answered locally; anything else fails the test.
const routes = new Map<string, (init?: RequestInit) => unknown>([
  ['https://appleid.apple.com/auth/keys', () => ({ keys: [jwk] })],
  ['https://www.googleapis.com/oauth2/v3/certs', () => ({ keys: [jwk] })],
  ['https://appleid.apple.com/auth/token', () => ({ refresh_token: 'apple-refresh' })],
]);
let googleIdToken = '';
/** What Google's token endpoint answers next (Batch K: a refused client secret, a refused code). */
let googleTokenReply: () => Response | unknown = () => ({ id_token: googleIdToken });
let googleTokenBody: URLSearchParams | null = null;
routes.set('https://oauth2.googleapis.com/token', (init) => {
  googleTokenBody = new URLSearchParams(String(init?.body ?? ''));
  return googleTokenReply();
});

beforeAll(() => {
  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    const route = routes.get(url.split('?')[0]!);
    if (!route) throw new Error(`unexpected fetch ${url}`);
    const reply = route(init);
    return reply instanceof Response ? reply : Response.json(reply);
  });
});

describe('Sign in with Apple, iOS (SPEC §10.2)', () => {
  const raw = 'a-raw-nonce-of-decent-length';

  it('verifies the identity token and nonce, and keeps the refresh token encrypted', async () => {
    const token = await idToken('https://appleid.apple.com', 'com.devilsense.folio', { sub: 'apple-1', email: 'x@privaterelay.appleid.com', email_verified: 'true', nonce: await sha256Hex(raw) });
    const response = await api('/auth/apple/native', { method: 'POST', json: { identityToken: token, rawNonce: raw, authorizationCode: 'c1', deviceName: 'iPhone', adult: true } });
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
      const response = await api('/auth/apple/native', { method: 'POST', json: { identityToken: token, rawNonce: raw, deviceName: 'iPhone', adult: true } });
      expect(response.status).toBe(401);
    }
  });

  it('re-authentication marks the current session instead of creating one', async () => {
    const first = await idToken('https://appleid.apple.com', 'com.devilsense.folio', { sub: 'apple-re', nonce: await sha256Hex(raw) });
    const signedIn = await (await api('/auth/apple/native', { method: 'POST', json: { identityToken: first, rawNonce: raw, deviceName: 'iPhone', adult: true } })).json<{ token: string }>();
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
    const startResponse = await api(`/auth/google/start?platform=ios&adult=1&challenge=${await sha256Base64url(verifier)}`);
    expect(startResponse.status).toBe(302);
    const location = new URL(startResponse.headers.get('location')!);
    expect(location.host).toBe('accounts.google.com');
    expect(location.searchParams.get('scope')).toBe('openid email');
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
    // The state can't be replayed either: back to the app with "expired", never a JSON page.
    const replay = await api(`/auth/callback/google?state=${state}&code=abc`);
    expect(replay.headers.get('location')).toBe('folio://auth?error=expired');
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
    const noCookie = await api(`/auth/callback/google?state=${state}&code=abc`);
    expect(noCookie.status).toBe(303);
    expect(noCookie.headers.get('location')).toBe('/app?error=expired');
  });
});

describe('Google sign-in failures say why (Batch K)', () => {
  const verifier = 'k'.repeat(43);

  /** Start → Google → callback; returns where the callback sends the app. */
  async function callback(sub: string, email: string, code = 'abc') {
    await env.DB.prepare('DELETE FROM rate_limits').run();
    const start = await api(`/auth/google/start?platform=ios&adult=1&challenge=${await sha256Base64url(verifier)}`);
    const location = new URL(start.headers.get('location')!);
    const state = location.searchParams.get('state')!;
    expect(state.startsWith('i.')).toBe(true);
    googleIdToken = await idToken('https://accounts.google.com', env.GOOGLE_CLIENT_ID, { sub, email, email_verified: true, nonce: location.searchParams.get('nonce')! });
    return (await api(`/auth/callback/google?state=${state}&code=${code}`)).headers.get('location')!;
  }

  afterEach(() => { googleTokenReply = () => ({ id_token: googleIdToken }); });

  it('a refused client secret (the build 94 bug) is "google_unavailable", not a generic failure', async () => {
    googleTokenReply = () => Response.json({ error: 'invalid_client', error_description: 'The provided client secret is invalid.' }, { status: 401 });
    expect(await callback('g-k1', 'k1@gmail.com')).toBe('folio://auth?error=google_unavailable');
  });

  it('a refused code (expired, used, PKCE) is "expired", so trying again is the advice', async () => {
    googleTokenReply = () => Response.json({ error: 'invalid_grant' }, { status: 400 });
    expect(await callback('g-k2', 'k2@gmail.com')).toBe('folio://auth?error=expired');
  });

  it('an expired iOS state goes back to the app, not a JSON page in the sign-in sheet', async () => {
    const start = await api(`/auth/google/start?platform=ios&adult=1&challenge=${await sha256Base64url(verifier)}`);
    const state = new URL(start.headers.get('location')!).searchParams.get('state')!;
    await env.DB.prepare('UPDATE oauth_states SET expires_at = 0').run();
    const response = await api(`/auth/callback/google?state=${state}&code=abc`);
    expect(response.headers.get('location')).toBe('folio://auth?error=expired');
  });

  it('a Google email that already has an account links to it (no second user)', async () => {
    const existing = await makeUser('same.person@gmail.com');
    const location = await callback('g-k3', 'Same.Person@gmail.com');
    const code = new URL(location).searchParams.get('code')!;
    const signIn = await (await api('/auth/exchange', { method: 'POST', json: { code, verifier, deviceName: 'iPhone' } })).json<{ userId: string; isNew: boolean }>();
    expect(signIn).toMatchObject({ userId: existing.userId, isNew: false });
    const users = await env.DB.prepare(`SELECT COUNT(*) AS n FROM users WHERE email = 'same.person@gmail.com'`).first<{ n: number }>();
    expect(users?.n).toBe(1);
    // And again: the Google account itself is now linked.
    const again = new URL(await callback('g-k3', 'same.person@gmail.com')).searchParams.get('code')!;
    expect((await (await api('/auth/exchange', { method: 'POST', json: { code: again, verifier, deviceName: 'iPhone' } })).json<{ userId: string }>()).userId).toBe(existing.userId);
  });

  it('an account that is being deleted says so', async () => {
    const location = await callback('g-k4', 'k4@gmail.com');
    const code = new URL(location).searchParams.get('code')!;
    const { userId } = await (await api('/auth/exchange', { method: 'POST', json: { code, verifier, deviceName: 'iPhone' } })).json<{ userId: string }>();
    await env.DB.prepare('UPDATE users SET deleting = 1 WHERE id = ?1').bind(userId).run();
    expect(await callback('g-k4', 'k4@gmail.com')).toBe('folio://auth?error=account_deleting');
  });

  it('trims a secret pasted with a newline', async () => {
    const result = await exchangeGoogleCode({ ...env, GOOGLE_CLIENT_SECRET: ' test-google-secret\n' }, 'abc', verifier);
    expect('idToken' in result).toBe(true);
    expect(googleTokenBody?.get('client_secret')).toBe('test-google-secret');
    expect(await exchangeGoogleCode({ ...env, GOOGLE_CLIENT_SECRET: '' }, 'abc', verifier)).toEqual({ problem: 'config' });
  });
});
