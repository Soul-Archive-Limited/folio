/** Public identifiers for the web app (SPEC §13.1: designed to be public). */
export const appConfig = {
  /** Cloudflare Turnstile site key for folio.devilsense.com (Batch F). */
  turnstileSiteKey: '0x4AAAAAAFqv5QjY0E8gzTEm',
  /** Cloudflare's always-pass test key, used only on localhost. */
  turnstileTestKey: '1x00000000000000000000AA',
} as const;

export const turnstileKey = () =>
  ['localhost', '127.0.0.1'].includes(location.hostname) ? appConfig.turnstileTestKey : appConfig.turnstileSiteKey;
