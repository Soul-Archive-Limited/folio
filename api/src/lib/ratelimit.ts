import type { Env } from '../env';
import { hmacHex } from './crypto';
import { fail } from './errors';

/**
 * Fixed-window counter in D1 for limits longer than a minute (SPEC §10.7). One row write
 * per call. Over the limit → 429 with Retry-After.
 */
export async function limit(env: Env, key: string, max: number, windowSeconds: number, now = Date.now()): Promise<void> {
  const windowStart = Math.floor(now / 1000 / windowSeconds) * windowSeconds;
  const row = await env.DB.prepare(
    `INSERT INTO rate_limits (key, window_start, count) VALUES (?1, ?2, 1)
     ON CONFLICT (key) DO UPDATE SET
       count = CASE WHEN rate_limits.window_start = excluded.window_start THEN rate_limits.count + 1 ELSE 1 END,
       window_start = excluded.window_start
     RETURNING count`,
  ).bind(key, windowStart).first<{ count: number }>();
  if ((row?.count ?? 0) > max) {
    const retryAfter = windowStart + windowSeconds - Math.floor(now / 1000);
    fail(429, 'rate_limited', { 'retry-after': String(Math.max(retryAfter, 1)) });
  }
}

/** Per-minute burst guard via the rate-limiting binding (per Cloudflare location). */
export async function burst(env: Env, key: string): Promise<void> {
  const { success } = await env.BURST.limit({ key });
  if (!success) fail(429, 'rate_limited', { 'retry-after': '60' });
}

export function clientIP(request: Request): string {
  return request.headers.get('cf-connecting-ip') ?? 'unknown';
}

/** The caller's IP as a rate-limit key: keyed-hashed, so D1 never holds raw IP addresses
 *  (rows are kept two days; Phase 14 privacy review, DECISIONS 210). */
export async function ipKey(env: Env, request: Request): Promise<string> {
  return (await hmacHex(env.OTP_PEPPER, `ip|${clientIP(request)}`)).slice(0, 32);
}
