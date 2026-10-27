import { env, SELF } from 'cloudflare:test';
import { createSession } from '../src/lib/session';

export const ORIGIN = 'https://folio.devilsense.com';

export interface TestUser {
  userId: string;
  token: string;
  sessionId: string;
}

/** A user with one iOS session, created directly (the sign-in flows have their own tests). */
export async function makeUser(email = `${crypto.randomUUID()}@example.com`): Promise<TestUser> {
  const userId = crypto.randomUUID();
  await env.DB.prepare('INSERT INTO users (id, email, created_at) VALUES (?1, ?2, ?3)').bind(userId, email, Date.now()).run();
  await env.DB.prepare(`INSERT INTO accounts (id, user_id, provider, provider_user_id, email, created_at) VALUES (?1, ?2, 'email', ?3, ?3, ?4)`)
    .bind(crypto.randomUUID(), userId, email, Date.now()).run();
  const session = await createSession(env, userId, 'ios', 'Test iPhone');
  return { userId, token: session.token, sessionId: session.sessionId };
}

export async function secondSession(user: TestUser, name = 'Test Mac'): Promise<TestUser> {
  const session = await createSession(env, user.userId, 'web', name);
  return { userId: user.userId, token: session.token, sessionId: session.sessionId };
}

export function api(path: string, init: RequestInit & { token?: string; json?: unknown } = {}): Promise<Response> {
  const headers = new Headers(init.headers);
  if (init.token) headers.set('authorization', `Bearer ${init.token}`);
  let bodyInit = init.body;
  if (init.json !== undefined) {
    headers.set('content-type', 'application/json');
    bodyInit = JSON.stringify(init.json);
  }
  return SELF.fetch(`${ORIGIN}/api${path}`, { ...init, headers, body: bodyInit, redirect: 'manual' });
}

export const b64 = (text: string) => btoa(text);

export function record(id = crypto.randomUUID(), overrides: Record<string, unknown> = {}) {
  return { id, type: 'entry', ciphertext: b64(`cipher-${id}-${Math.random()}`), nonce: b64('123456789012'), clientUpdatedAt: Date.now(), baseVersion: null, deleted: false, ...overrides };
}
