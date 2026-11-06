import type { Env } from '../env';

/** Cloudflare Turnstile server-side check for the web email-code request (SPEC §10.1). */
export async function verifyTurnstile(env: Env, token: string | undefined, ip: string): Promise<boolean> {
  if (!token || !env.TURNSTILE_SECRET) return false;
  const response = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    body: new URLSearchParams({ secret: env.TURNSTILE_SECRET, response: token, remoteip: ip }),
  });
  if (!response.ok) return false;
  const result = await response.json<{ success?: boolean; hostname?: string; action?: string }>();
  // Batch L review: the token must come from our page and our email-code widget, not any site's.
  if (env.TURNSTILE_HOSTNAME && result.hostname !== env.TURNSTILE_HOSTNAME) return false;
  if (result.action !== undefined && result.action !== 'email-code') return false;
  return result.success === true;
}
