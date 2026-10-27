import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { Env } from '../env';
import { log } from '../lib/errors';

const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

export function googleRedirectURI(env: Env): string {
  return `${env.APP_ORIGIN}/api/auth/callback/google`;
}

/** Authorization code flow with PKCE; scopes `openid email profile` only (SPEC §10.2). */
export function googleAuthorizeURL(env: Env, state: string, codeChallenge: string, nonce: string): string {
  const url = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  url.search = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: googleRedirectURI(env),
    response_type: 'code',
    scope: 'openid email profile',
    state,
    nonce,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
    prompt: 'select_account',
  }).toString();
  return url.toString();
}

export async function exchangeGoogleCode(env: Env, code: string, codeVerifier: string): Promise<string | null> {
  if (!env.GOOGLE_CLIENT_SECRET) throw new Error('google not configured');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      code, client_id: env.GOOGLE_CLIENT_ID, client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: googleRedirectURI(env), grant_type: 'authorization_code', code_verifier: codeVerifier,
    }),
  });
  if (!response.ok) {
    log('warn', 'google_code_exchange_failed', { status: response.status });
    return null;
  }
  return (await response.json<{ id_token?: string }>()).id_token ?? null;
}

export async function verifyGoogleIdToken(env: Env, token: string, nonce: string) {
  const { payload } = await jwtVerify(token, googleKeys, {
    issuer: ['https://accounts.google.com', 'accounts.google.com'], audience: env.GOOGLE_CLIENT_ID, algorithms: ['RS256'],
  });
  if (payload.nonce !== nonce || typeof payload.sub !== 'string') throw new Error('nonce or subject');
  return {
    sub: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : null,
    emailVerified: payload.email_verified === true,
  };
}
