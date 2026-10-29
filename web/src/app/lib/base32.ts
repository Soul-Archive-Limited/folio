/** Crockford base32 for the 128-bit recovery key (SPEC §10.4), as `CrockfordBase32.swift`. */

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

export function encodeBase32(bytes: Uint8Array): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

/** Reads a typed key: any case, spaces and hyphens ignored, O→0 and I/L→1. */
export function decodeBase32(text: string, byteCount = 16): Uint8Array | null {
  const clean = text.toUpperCase().replace(/[\s-]/g, '').replace(/O/g, '0').replace(/[IL]/g, '1');
  if (clean.length !== Math.ceil((byteCount * 8) / 5)) return null;
  const out = new Uint8Array(byteCount);
  let bits = 0;
  let value = 0;
  let index = 0;
  for (const character of clean) {
    const digit = ALPHABET.indexOf(character);
    if (digit < 0) return null;
    value = ((value << 5) | digit) & 0xffff;
    bits += 5;
    if (bits >= 8) {
      if (index < byteCount) out[index++] = (value >>> (bits - 8)) & 255;
      bits -= 8;
    }
  }
  return index === byteCount ? out : null;
}

/** Two balanced lines of 13, each 4-5-4 (DECISIONS 191). */
export function recoveryKeyLines(key: string): [string, string] {
  const group = (line: string) => [line.slice(0, 4), line.slice(4, 9), line.slice(9)].join('-');
  return [group(key.slice(0, 13)), group(key.slice(13))];
}
