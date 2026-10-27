import type { UserHub } from './hub/UserHub';

/** Bindings and vars (wrangler.jsonc) plus secrets (`wrangler secret put`). */
export interface Env {
  DB: D1Database;
  BLOBS: R2Bucket;
  USER_HUB: DurableObjectNamespace<UserHub>;
  BURST: RateLimit;

  APP_ORIGIN: string;
  APPLE_BUNDLE_ID: string;
  APPLE_SERVICES_ID: string;
  APPLE_TEAM_ID: string;
  APPLE_KEY_ID: string;
  GOOGLE_CLIENT_ID: string;
  EMAIL_FROM: string;
  REVIEW_EMAIL: string;
  REVIEW_ENABLED: string;
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUD: string;

  // Secrets
  APPLE_PRIVATE_KEY?: string;
  GOOGLE_CLIENT_SECRET?: string;
  RESEND_API_KEY?: string;
  TURNSTILE_SECRET?: string;
  OTP_PEPPER: string;
  TOKEN_ENCRYPTION_KEY: string;
  REVIEW_CODE?: string;

  /** Tests only: route sign-in emails to the outbox instead of Resend. */
  EMAIL_OUTBOX?: string;
}

export interface SessionInfo {
  sessionId: string;
  userId: string;
  platform: 'ios' | 'web';
  reauthAt: number | null;
}

export type AppEnv = { Bindings: Env; Variables: { session: SessionInfo; requestId: string } };
