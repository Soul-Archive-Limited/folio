import { DurableObject } from 'cloudflare:workers';
import type { Env } from '../env';
import { revokeApple } from '../auth/apple';
import { hmacHex, openToken } from '../lib/crypto';
import { accountDeletedEmail, emailSender } from '../lib/email';
import { log } from '../lib/errors';

interface Wipe {
  userId: string;
  email: string | null;
}

/**
 * One per user (SPEC §10.1, §10.5): holds that user's open WebSockets with the Hibernation
 * API and tells them "something changed" after a push. Pings get an automatic "pong" that
 * never wakes the object, so open, idle sockets cost nothing. Also runs the account wipe in
 * alarm steps, so a large account never exceeds one invocation's limits.
 */
export class UserHub extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  /** Accepts a WebSocket the Worker has already authenticated (`x-folio-session`). */
  override async fetch(request: Request): Promise<Response> {
    const sessionId = request.headers.get('x-folio-session');
    if (request.headers.get('upgrade') !== 'websocket' || !sessionId) return new Response(null, { status: 400 });
    if (await this.ctx.storage.get<Wipe>('wipe')) return new Response(null, { status: 410 });
    const { 0: client, 1: server } = new WebSocketPair();
    this.ctx.acceptWebSocket(server, [sessionId]);
    const cursor = Number(request.headers.get('x-folio-cursor'));
    if (Number.isInteger(cursor) && cursor >= 0) server.send(JSON.stringify({ cursor }));
    return new Response(null, { status: 101, webSocket: client });
  }

  /** After an accepted push: every other device of this user pulls. */
  async notify(cursor: number, exceptSessionId: string): Promise<void> {
    const message = JSON.stringify({ cursor });
    for (const socket of this.ctx.getWebSockets()) {
      if (this.ctx.getTags(socket).includes(exceptSessionId)) continue;
      try { socket.send(message); } catch { /* closing */ }
    }
  }

  async notifyLink(linkId: string): Promise<void> {
    const message = JSON.stringify({ link: linkId });
    for (const socket of this.ctx.getWebSockets()) {
      try { socket.send(message); } catch { /* closing */ }
    }
  }

  /** A signed-out device's socket closes too. */
  async disconnect(sessionId: string): Promise<void> {
    for (const socket of this.ctx.getWebSockets(sessionId)) socket.close(4001, 'signed out');
  }

  override async webSocketMessage(): Promise<void> {
    // Clients only send "ping", answered automatically; anything else is ignored.
  }

  override async webSocketClose(socket: WebSocket, code: number): Promise<void> {
    try { socket.close(code === 1005 ? 1000 : code, 'bye'); } catch { /* already closed */ }
  }

  // MARK: Account wipe (SPEC §10.6)

  async startWipe(userId: string, email: string | null): Promise<void> {
    await this.ctx.storage.put<Wipe>('wipe', { userId, email });
    for (const socket of this.ctx.getWebSockets()) socket.close(4002, 'account deleted');
    await this.ctx.storage.setAlarm(Date.now());
  }

  override async alarm(): Promise<void> {
    const wipe = await this.ctx.storage.get<Wipe>('wipe');
    if (!wipe) return;
    // R2 first, a page at a time; the alarm comes back until the prefix is empty.
    const listing = await this.env.BLOBS.list({ prefix: `u/${wipe.userId}/`, limit: 1000 });
    if (listing.objects.length > 0) await this.env.BLOBS.delete(listing.objects.map((object) => object.key));
    if (listing.truncated) {
      await this.ctx.storage.setAlarm(Date.now() + 500);
      return;
    }
    await this.revokeProviderTokens(wipe.userId);
    const db = this.env.DB;
    const id = wipe.userId;
    await db.batch([
      db.prepare('DELETE FROM records WHERE user_id = ?1').bind(id),
      db.prepare('DELETE FROM blobs WHERE user_id = ?1').bind(id),
      db.prepare('DELETE FROM key_envelopes WHERE user_id = ?1').bind(id),
      db.prepare('DELETE FROM link_requests WHERE user_id = ?1').bind(id),
      db.prepare('DELETE FROM handoff_codes WHERE user_id = ?1').bind(id),
      db.prepare('DELETE FROM sessions WHERE user_id = ?1').bind(id),
      db.prepare('DELETE FROM accounts WHERE user_id = ?1').bind(id),
      db.prepare('DELETE FROM users WHERE id = ?1').bind(id),
      db.prepare('INSERT INTO deletions_log (id_hash, deleted_at) VALUES (?1, ?2)').bind(await hmacHex(this.env.OTP_PEPPER, `deleted|${id}`), Date.now()),
    ]);
    if (wipe.email) {
      const sender = emailSender(this.env);
      if (sender) await sender.send(accountDeletedEmail(wipe.email), `deleted-${await hmacHex(this.env.OTP_PEPPER, id)}`);
    }
    await this.ctx.storage.deleteAll();
    log('info', 'account_wiped');
  }

  private async revokeProviderTokens(userId: string): Promise<void> {
    const rows = await this.env.DB.prepare(`SELECT refresh_token_enc FROM accounts WHERE user_id = ?1 AND provider = 'apple' AND refresh_token_enc IS NOT NULL`)
      .bind(userId).all<{ refresh_token_enc: string }>();
    for (const row of rows.results) {
      try {
        const [clientId, token] = (await openToken(this.env.TOKEN_ENCRYPTION_KEY, row.refresh_token_enc)).split('|');
        if (clientId && token) await revokeApple(this.env, clientId, token);
      } catch {
        log('warn', 'apple_revoke_skipped');
      }
    }
    // Google: only `openid email profile` and no refresh token is ever stored, so nothing to revoke.
  }
}
