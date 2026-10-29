/**
 * Same-origin calls to the Worker (`/api/*`, SPEC §1). The session is the HttpOnly
 * `__Host-folio_session` cookie; state-changing requests carry the page's Origin, which the
 * Worker checks (CSRF, SPEC §10.2).
 */

export class ApiError extends Error {
  constructor(readonly status: number, readonly code: string, readonly retryAfter?: number) {
    super(code);
  }
  get isNetwork() { return this.status === 0; }
  get isRetryable() { return this.status === 0 || this.status === 429 || this.status >= 500; }
}

export async function api<T>(method: string, path: string, body?: unknown, init: RequestInit = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`/api/${path}`, {
      method,
      credentials: 'same-origin',
      cache: 'no-store',
      ...init,
      headers: body !== undefined && !(body instanceof Uint8Array) ? { 'content-type': 'application/json', ...init.headers } : init.headers,
      body: body === undefined ? undefined : body instanceof Uint8Array ? (body as BodyInit) : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, 'offline');
  }
  if (!response.ok) {
    let code = 'server_error';
    try { code = ((await response.json()) as { error?: string }).error ?? code; } catch { /* not JSON */ }
    const retry = Number(response.headers.get('retry-after'));
    throw new ApiError(response.status, code, Number.isFinite(retry) && retry > 0 ? retry : undefined);
  }
  if (response.status === 204) return undefined as T;
  const type = response.headers.get('content-type') ?? '';
  return (type.includes('application/json') ? response.json() : new Uint8Array(await response.arrayBuffer())) as Promise<T>;
}

export interface Me {
  userId: string;
  sessionId: string;
  platform: string;
  email: string | null;
  createdAt: number;
  providers: string[];
  hasRecoveryKey: boolean;
  usage: { records: number; photoBytes: number };
}

export interface Device {
  id: string;
  name: string;
  platform: string;
  createdAt: number;
  lastSeenAt: number;
  current: boolean;
  label: { ciphertext: string; nonce: string } | null;
}

export interface Remote {
  id: string;
  type: string;
  version: number;
  ciphertext: string;
  nonce: string;
  clientUpdatedAt: number;
  deleted: boolean;
}

/** Plain-language messages for errors a person can act on (SPEC §6.14: never raw codes). */
export function friendly(error: unknown): string {
  if (!(error instanceof ApiError)) return 'Something went wrong. Please try again.';
  if (error.isNetwork) return 'You seem to be offline. Check your connection and try again.';
  switch (error.code) {
    case 'rate_limited': return 'Too many tries. Please wait a little and try again.';
    case 'invalid_code': return "That code didn't work. Check it, or send a new one.";
    case 'turnstile': return 'Please complete the check above and try again.';
    case 'quota_photos': return 'Your photo storage is full (1 GB). Delete some photos to add more.';
    case 'quota_records': return 'Your diary has reached 50,000 items.';
    case 'reauth_required': return "Please confirm it's you again.";
    case 'too_large': return "That's too large to upload.";
    default: return error.status >= 500 ? 'Our server had a problem. Your changes are safe here — try again in a moment.' : 'Something went wrong. Please try again.';
  }
}
