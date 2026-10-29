import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { api } from './helpers';

describe('privacy (Phase 14)', () => {
  it('keeps no raw IP address in rate-limit rows', async () => {
    const ip = '203.0.113.77';
    await api('/auth/email/start', { method: 'POST', json: { email: 'ip-check@example.com' }, headers: { 'cf-connecting-ip': ip } });
    const rows = await env.DB.prepare('SELECT key FROM rate_limits').all<{ key: string }>();
    expect(rows.results.some((row) => row.key.startsWith('email-start-ip:'))).toBe(true);
    expect(rows.results.some((row) => row.key.includes(ip))).toBe(false);
  });
});
