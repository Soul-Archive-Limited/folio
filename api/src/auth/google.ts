import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { Env } from '../env';
import { log } from '../lib/errors';

const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

export function googleRedirectURI(env: Env): string {
  return `${env.APP_ORIGIN}/api/auth/callback/google`;
}

/** Authorization code flow with PKCE; scopes `openid email` only (SPEC §10.2; Batch L dropped
 *  `profile`, which would send name and picture that Folio never uses). */
export function googleAuthorizeURL(env: Env, state: string, codeChallenge: string, nonce: string): string {
  const url = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  url.search = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID.trim(),
    redirect_uri: googleRedirectURI(env),
    response_type: 'code',
    scope: 'openid email',
    state,
    nonce,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
    prompt: 'select_account',
  }).toString();
  return url.toString();
}

/**
 * Why a code exchange failed: `config` = Google refused our client credentials (a wrong or
 * rotated `GOOGLE_CLIENT_SECRET`, Batch K) — nobody can sign in until it's fixed; `code` = this
 * one sign-in's code was refused (expired, used, PKCE mismatch) — trying again works.
 */
export type GoogleExchange = { idToken: string } | { problem: 'config' | 'code' };

export async function exchangeGoogleCode(env: Env, code: string, codeVerifier: string): Promise<GoogleExchange> {
  // Trimmed: a secret pasted with a trailing newline or space is refused as invalid_client.
  const secret = env.GOOGLE_CLIENT_SECRET?.trim();
  if (!secret) {
    log('error', 'google_not_configured');
    return { problem: 'config' };
  }
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      code, client_id: env.GOOGLE_CLIENT_ID.trim(), client_secret: secret,
      redirect_uri: googleRedirectURI(env), grant_type: 'authorization_code', code_verifier: codeVerifier,
    }),
  });
  if (!response.ok) {
    // Google's error code (e.g. invalid_client, invalid_grant) is safe to log; its description isn't kept.
    const error = (await response.json<{ error?: unknown }>().catch(() => ({ error: undefined }))).error;
    const googleError = typeof error === 'string' ? error.slice(0, 40) : null;
    const problem = googleError === 'invalid_client' || googleError === 'unauthorized_client' || response.status === 401 ? 'config' : 'code';
    log(problem === 'config' ? 'error' : 'warn', 'google_code_exchange_failed', { status: response.status, googleError });
    return { problem };
  }
  const idToken = (await response.json<{ id_token?: string }>()).id_token;
  if (!idToken) {
    log('warn', 'google_code_exchange_failed', { status: response.status, googleError: 'no_id_token' });
    return { problem: 'code' };
  }
  return { idToken };
}

export async function verifyGoogleIdToken(env: Env, token: string, nonce: string) {
  const { payload } = await jwtVerify(token, googleKeys, {
    issuer: ['https://accounts.google.com', 'accounts.google.com'], audience: env.GOOGLE_CLIENT_ID.trim(), algorithms: ['RS256'],
  });
  if (payload.nonce !== nonce || typeof payload.sub !== 'string') throw new Error('nonce or subject');
  return {
    sub: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : null,
    emailVerified: payload.email_verified === true,
  };
}
