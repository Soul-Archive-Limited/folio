import { SignJWT, createRemoteJWKSet, importPKCS8, jwtVerify } from 'jose';
import type { Env } from '../env';
import { log } from '../lib/errors';

const APPLE_ISSUER = 'https://appleid.apple.com';
const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export interface AppleClaims {
  sub: string;
  email: string | null;
  emailVerified: boolean;
  nonce: string | null;
}

/** Verifies an Apple identity token against Apple's JWKS (SPEC §10.2). */
export async function verifyAppleIdToken(token: string, audience: string): Promise<AppleClaims> {
  const { payload } = await jwtVerify(token, appleKeys, { issuer: APPLE_ISSUER, audience, algorithms: ['RS256'] });
  if (typeof payload.sub !== 'string') throw new Error('no subject');
  const verified = payload.email_verified === true || payload.email_verified === 'true';
  return {
    sub: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : null,
    emailVerified: verified,
    nonce: typeof payload.nonce === 'string' ? payload.nonce : null,
  };
}

/** The client secret Apple wants: an ES256 JWT signed with the Sign in with Apple key. */
export async function appleClientSecret(env: Env, clientId: string, now = Date.now()): Promise<string> {
  if (!env.APPLE_PRIVATE_KEY || !env.APPLE_KEY_ID) throw new Error('apple key not configured');
  const key = await importPKCS8(env.APPLE_PRIVATE_KEY, 'ES256');
  const iat = Math.floor(now / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: env.APPLE_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID)
    .setIssuedAt(iat)
    .setExpirationTime(iat + 300)
    .setAudience(APPLE_ISSUER)
    .setSubject(clientId)
    .sign(key);
}

/** Exchanges an authorization code; returns the refresh token (kept for revocation). */
export async function exchangeAppleCode(env: Env, code: string, clientId: string, redirectUri?: string): Promise<{ refreshToken: string | null; idToken: string | null }> {
  const body = new URLSearchParams({ client_id: clientId, client_secret: await appleClientSecret(env, clientId), code, grant_type: 'authorization_code' });
  if (redirectUri) body.set('redirect_uri', redirectUri);
  const response = await fetch('https://appleid.apple.com/auth/token', { method: 'POST', body });
  if (!response.ok) {
    log('warn', 'apple_code_exchange_failed', { status: response.status });
    return { refreshToken: null, idToken: null };
  }
  const json = await response.json<{ refresh_token?: string; id_token?: string }>();
  return { refreshToken: json.refresh_token ?? null, idToken: json.id_token ?? null };
}

/**
 * Revokes a refresh token on account deletion (App Store 5.1.1(v), TN3194). Apple answers 200
 * even for unknown tokens, so success here is logged, not proof.
 */
export async function revokeApple(env: Env, clientId: string, refreshToken: string): Promise<boolean> {
  const body = new URLSearchParams({
    client_id: clientId, client_secret: await appleClientSecret(env, clientId), token: refreshToken, token_type_hint: 'refresh_token',
  });
  const response = await fetch('https://appleid.apple.com/auth/revoke', { method: 'POST', body });
  log(response.ok ? 'info' : 'warn', 'apple_revoke', { status: response.status });
  return response.ok;
}

export function appleAuthorizeURL(env: Env, state: string, nonce: string): string {
  const url = new URL('https://appleid.apple.com/auth/authorize');
  url.search = new URLSearchParams({
    client_id: env.APPLE_SERVICES_ID,
    redirect_uri: `${env.APP_ORIGIN}/api/auth/callback/apple`,
    response_type: 'code',
    response_mode: 'form_post',
    scope: 'name email',
    state,
    nonce,
  }).toString();
  return url.toString();
}
