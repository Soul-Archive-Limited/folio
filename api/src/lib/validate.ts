import type { Context } from 'hono';
import { z } from 'zod';
import { fail } from './errors';

/** Parses a JSON body with zod; anything else is a generic 400 (SPEC §13.7). */
export async function body<T extends z.ZodType>(c: Context, schema: T): Promise<z.infer<T>> {
  let raw: unknown;
  try {
    raw = await c.req.json();
  } catch {
    fail(400, 'invalid_request');
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) fail(400, 'invalid_request');
  return parsed.data;
}

export const deviceName = z.string().trim().min(1).max(64).transform((s) => s.replace(/[\u0000-\u001f\u007f]/g, ''));
export const uuid = z.uuid();
export const base64Text = (max: number) => z.string().max(max).regex(/^[A-Za-z0-9+/_-]*={0,2}$/);
