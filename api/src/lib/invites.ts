import type { Env } from '../env';
import { hmacHex } from './crypto';
import { fail } from './errors';

/** Invite-only sign-up (Batch J). */
export const INVITE_TTL = 7 * 24 * 60 * 60 * 1000;
export const MAX_OPEN_INVITES = 20;
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford base32

/** Eight random Crockford characters, shown as "ABCD-EFGH" (40 bits; tries are rate-limited). */
export function newInviteCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  const chars = [...bytes].map((b) => ALPHABET[b & 31]).join('');
  return `${chars.slice(0, 4)}-${chars.slice(4)}`;
}

/** What a person typed, as the canonical 8 characters, or null if it can't be an invite. */
export function normaliseInvite(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const cleaned = raw.toUpperCase().replace(/[\s-]/g, '').replace(/O/g, '0').replace(/[IL]/g, '1');
  return /^[0-9A-HJKMNP-TV-Z]{8}$/.test(cleaned) ? cleaned : null;
}

export async function inviteHash(env: Env, code: string): Promise<string> {
  return hmacHex(env.OTP_PEPPER, `invite|${code}`);
}

/** The hash for a presented invite; a malformed one is refused the same way as a wrong one. */
export async function presentedInviteHash(env: Env, raw: string | null | undefined): Promise<string | null> {
  if (raw === null || raw === undefined || raw === '') return null;
  const code = normaliseInvite(raw);
  if (!code) fail(403, 'invite_invalid');
  return inviteHash(env, code);
}

export function invitesRequired(env: Env): boolean {
  return env.INVITES_REQUIRED !== 'false';
}

function ownerEmails(env: Env): string[] {
  return (env.OWNER_EMAILS ?? '').split(',').map((e) => e.trim().toLowerCase()).filter(Boolean);
}

export function isOwnerEmail(env: Env, email: string | null): boolean {
  return !!email && ownerEmails(env).includes(email.toLowerCase());
}

/** Whether creating an account for `email` needs an invite: not the owner, not App Review. */
export function needsInvite(env: Env, email: string | null): boolean {
  if (!invitesRequired(env)) return false;
  if (isOwnerEmail(env, email)) return false;
  const review = env.REVIEW_ENABLED === 'true' && !!email && email === env.REVIEW_EMAIL.trim().toLowerCase();
  return !review;
}

/** An open invite exists for this hash (checked before anything single-use is spent). */
export async function inviteIsOpen(env: Env, hash: string, now = Date.now()): Promise<boolean> {
  const row = await env.DB.prepare('SELECT 1 AS open FROM invites WHERE code_hash = ?1 AND used_at IS NULL AND revoked_at IS NULL AND expires_at > ?2')
    .bind(hash, now).first();
  return row !== null;
}

/** Marks the invite used by `userId`; refuses if it was used, revoked or expired meanwhile. */
export async function redeemInvite(env: Env, hash: string, userId: string, now = Date.now()): Promise<void> {
  const row = await env.DB.prepare(
    `UPDATE invites SET used_by = ?2, used_at = ?3
     WHERE code_hash = ?1 AND used_at IS NULL AND revoked_at IS NULL AND expires_at > ?3 RETURNING id`,
  ).bind(hash, userId, now).first();
  if (!row) fail(403, 'invite_invalid');
}

/** The signed-in user may make invites: one of their sign-in emails is an owner email. */
export async function isOwner(env: Env, userId: string): Promise<boolean> {
  if (ownerEmails(env).length === 0) return false;
  const rows = await env.DB.prepare('SELECT email FROM users WHERE id = ?1 UNION SELECT email FROM accounts WHERE user_id = ?1').bind(userId).all<{ email: string | null }>();
  return rows.results.some((r) => isOwnerEmail(env, r.email));
}
