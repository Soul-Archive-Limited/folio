import type { Env } from '../env';
import { fail } from '../lib/errors';

export type Provider = 'apple' | 'google' | 'email';

export interface Identity {
  provider: Provider;
  providerUserId: string;
  email: string | null;
  emailVerified: boolean;
  refreshTokenSealed?: string | null;
}

export function normaliseEmail(email: string): string {
  return email.trim().toLowerCase();
}

/**
 * Finds or creates the user for a verified identity (SPEC §10.2 linking): the same provider
 * account always maps to the same user; otherwise a verified email that matches an existing
 * user links to it (Apple private-relay addresses simply won't match); otherwise a new user.
 */
export async function resolveUser(env: Env, identity: Identity, now = Date.now()): Promise<{ userId: string; isNew: boolean }> {
  const email = identity.email ? normaliseEmail(identity.email) : null;
  const existing = await env.DB.prepare(
    `SELECT a.user_id FROM accounts a JOIN users u ON u.id = a.user_id
     WHERE a.provider = ?1 AND a.provider_user_id = ?2 AND u.deleting = 0`,
  ).bind(identity.provider, identity.providerUserId).first<{ user_id: string }>();
  if (!existing) {
    // The same sign-in still belongs to an account that's being deleted: wait for the wipe.
    const pending = await env.DB.prepare('SELECT 1 AS present FROM accounts WHERE provider = ?1 AND provider_user_id = ?2')
      .bind(identity.provider, identity.providerUserId).first();
    if (pending) fail(409, 'account_deleting');
  }
  if (existing) {
    if (identity.refreshTokenSealed) {
      await env.DB.prepare('UPDATE accounts SET refresh_token_enc = ?3 WHERE provider = ?1 AND provider_user_id = ?2')
        .bind(identity.provider, identity.providerUserId, identity.refreshTokenSealed).run();
    }
    return { userId: existing.user_id, isNew: false };
  }

  let userId: string | null = null;
  if (email && identity.emailVerified) {
    const byEmail = await env.DB.prepare('SELECT id FROM users WHERE email = ?1 AND deleting = 0 LIMIT 1').bind(email).first<{ id: string }>();
    userId = byEmail?.id ?? null;
  }
  const isNew = userId === null;
  const statements: D1PreparedStatement[] = [];
  if (!userId) {
    userId = crypto.randomUUID();
    statements.push(env.DB.prepare('INSERT INTO users (id, email, created_at) VALUES (?1, ?2, ?3)').bind(userId, email, now));
  }
  statements.push(env.DB.prepare(
    `INSERT INTO accounts (id, user_id, provider, provider_user_id, email, refresh_token_enc, created_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`,
  ).bind(crypto.randomUUID(), userId, identity.provider, identity.providerUserId, email, identity.refreshTokenSealed ?? null, now));
  await env.DB.batch(statements);
  return { userId, isNew };
}
