import { generateKeyPairSync } from 'node:crypto';
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

// Test-only key for Apple client-secret JWTs; generated per run, never written anywhere.
const appleKey = generateKeyPairSync('ec', { namedCurve: 'P-256' }).privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();

export default defineConfig(async () => ({
  plugins: [
    cloudflareTest({
      remoteBindings: false,
      wrangler: { configPath: './wrangler.jsonc' },
      miniflare: {
        bindings: {
          TEST_MIGRATIONS: await readD1Migrations('./migrations'),
          OTP_PEPPER: 'test-pepper',
          TOKEN_ENCRYPTION_KEY: 'test-token-key',
          REVIEW_CODE: '424242',
          EMAIL_OUTBOX: 'memory',
          TURNSTILE_SECRET: 'test-turnstile',
          APPLE_KEY_ID: 'TESTKEY123',
          APPLE_PRIVATE_KEY: appleKey,
          GOOGLE_CLIENT_ID: 'test-client.apps.googleusercontent.com',
          GOOGLE_CLIENT_SECRET: 'test-google-secret',
        },
      },
    }),
  ],
  // Vitest 5's on-disk module cache isn't readable from inside workerd (plugin 1.4.1).
  test: { setupFiles: ['./test/apply-migrations.ts'], fsModuleCache: false },
}));
