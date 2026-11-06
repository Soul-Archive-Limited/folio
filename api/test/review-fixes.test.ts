// Batch L independent review fixes: per-address daily limits that hold across networks, and
// re-authentication that needs a live session.
import { describe, expect, it } from 'vitest';
import { api } from './helpers';

const verify = (email: string, ip: string, extra: Record<string, unknown> = {}) =>
  api('/auth/email/verify', { method: 'POST', json: { email, code: '000000', client: 'ios', deviceName: 'iPhone', adult: true, ...extra }, headers: { 'cf-connecting-ip': ip } });

describe('review fixes', () => {
  it('caps code checks at 20 per address per day, whatever the network', async () => {
    const email = `target-${crypto.randomUUID()}@example.com`;
    for (let i = 0; i < 20; i++) expect((await verify(email, `198.51.100.${i}`)).status).toBe(400);
    expect((await verify(email, '198.51.100.99')).status).toBe(429);
  });

  it('a re-authentication without a session is refused before anything else', async () => {
    const response = await verify(`nobody-${crypto.randomUUID()}@example.com`, '198.51.100.200', { reauth: true });
    expect(response.status).toBe(401);
  });
});
