import type { Env } from '../env';
import { log } from './errors';

export interface Email {
  to: string;
  subject: string;
  text: string;
  html: string;
}

/** SPEC §10.1: Resend now; swappable for Cloudflare Email Service on Workers Paid. */
export interface EmailSender {
  send(email: Email, idempotencyKey: string): Promise<boolean>;
}

export class ResendSender implements EmailSender {
  constructor(private readonly apiKey: string, private readonly from: string) {}

  async send(email: Email, idempotencyKey: string): Promise<boolean> {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${this.apiKey}`,
        'content-type': 'application/json',
        'idempotency-key': idempotencyKey,
      },
      body: JSON.stringify({ from: this.from, to: [email.to], subject: email.subject, text: email.text, html: email.html }),
    });
    if (!response.ok) log('error', 'email_send_failed', { status: response.status });
    return response.ok;
  }
}

/** Tests: keeps the last message per recipient in memory. */
export class OutboxSender implements EmailSender {
  static readonly sent = new Map<string, Email>();
  async send(email: Email): Promise<boolean> {
    OutboxSender.sent.set(email.to, email);
    return true;
  }
}

export function emailSender(env: Env): EmailSender | null {
  if (env.EMAIL_OUTBOX === 'memory') return new OutboxSender();
  if (!env.RESEND_API_KEY) return null;
  return new ResendSender(env.RESEND_API_KEY, env.EMAIL_FROM);
}

const escape = (s: string) => s.replace(/[&<>"']/g, (ch) => `&#${ch.charCodeAt(0)};`);

function layout(heading: string, body: string): string {
  return `<!doctype html><html><body style="margin:0;background:#F5F3EF;font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',Arial,sans-serif;color:#16161A">
<div style="max-width:480px;margin:0 auto;padding:40px 24px">
<p style="font-size:13px;letter-spacing:.06em;text-transform:uppercase;color:#B9441B;margin:0 0 16px">Folio</p>
<h1 style="font-size:24px;margin:0 0 16px">${escape(heading)}</h1>${body}
<p style="font-size:12px;color:#6b6b70;margin-top:32px">Soul Archive Ltd · Registered in England and Wales · Company no. 16186654</p>
</div></body></html>`;
}

export function signInCodeEmail(to: string, code: string): Email {
  return {
    to,
    subject: `${code} is your Folio code`,
    text: `Your Folio sign-in code is ${code}.\n\nIt works for 10 minutes. If you didn't ask for it, you can ignore this email.`,
    html: layout('Your sign-in code', `<p style="font-size:34px;font-weight:700;letter-spacing:.2em;margin:8px 0 16px">${escape(code)}</p>
<p style="font-size:15px;line-height:1.5">It works for 10 minutes. If you didn't ask for it, you can ignore this email.</p>`),
  };
}

export function accountDeletedEmail(to: string): Email {
  return {
    to,
    subject: 'Your Folio account was deleted',
    text: 'Your Folio account and everything stored with it on our servers has been deleted. Copies you chose to keep on your devices are still there.\n\nIf you didn\'t do this, reply to support@devilsense.com.',
    html: layout('Your account was deleted', `<p style="font-size:15px;line-height:1.5">Your Folio account and everything stored with it on our servers has been deleted. Copies you chose to keep on your devices are still there.</p>
<p style="font-size:15px;line-height:1.5">If you didn't do this, write to support@devilsense.com.</p>`),
  };
}
