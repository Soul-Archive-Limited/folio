import { HTTPException } from 'hono/http-exception';
import type { ContentfulStatusCode } from 'hono/utils/http-status';

/** Generic, stable error codes for clients; details only go to the logs (SPEC §13.7). */
export function fail(status: ContentfulStatusCode, code: string, headers?: Record<string, string>): never {
  throw new HTTPException(status, {
    res: new Response(JSON.stringify({ error: code }), {
      status,
      headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...headers },
    }),
  });
}

export function log(level: 'info' | 'warn' | 'error', event: string, fields: Record<string, string | number | boolean | null> = {}) {
  // Structured, and never request bodies, tokens, emails or ciphertext.
  console[level](JSON.stringify({ event, ...fields }));
}
