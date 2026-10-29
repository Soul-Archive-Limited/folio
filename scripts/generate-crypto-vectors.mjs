// Generates shared/crypto-vectors.json with WebCrypto (Node ≥ 22), independently of the
// iOS CryptoKit code. FolioCryptoTests must reproduce every value byte for byte, and the
// web app (Phase 12) tests against the same file. SPEC §10.3–10.4.
//
// Usage: node scripts/generate-crypto-vectors.mjs
// Inputs are fixed test values (never real keys); outputs are recomputed each run.
import { webcrypto as crypto } from 'node:crypto';
import { writeFileSync } from 'node:fs';

const subtle = crypto.subtle;
const hex = (buf) => Buffer.from(buf).toString('hex');
const unhex = (s) => new Uint8Array(Buffer.from(s, 'hex'));
const utf8 = (s) => new TextEncoder().encode(s);

const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
function crockford(bytes) {
  let bits = 0, value = 0, out = '';
  for (const b of bytes) {
    value = (value << 8) | b; bits += 8;
    while (bits >= 5) { out += CROCKFORD[(value >>> (bits - 5)) & 31]; bits -= 5; }
  }
  if (bits > 0) out += CROCKFORD[(value << (5 - bits)) & 31];
  return out;
}
// Two balanced lines of 13, each 4-5-4, so the last group is the 4 characters typed to confirm.
const grouped = (s) => [0, 4, 9, 13, 17, 22].map((at, i, all) => s.slice(at, all[i + 1] ?? s.length)).join('-');

async function aesGcm(keyBytes, nonce, plaintext, aad) {
  const key = await subtle.importKey('raw', keyBytes, 'AES-GCM', false, ['encrypt']);
  return new Uint8Array(await subtle.encrypt({ name: 'AES-GCM', iv: nonce, additionalData: aad, tagLength: 128 }, key, plaintext));
}

async function hkdf(ikm, salt, info, length = 32) {
  const key = await subtle.importKey('raw', ikm, 'HKDF', false, ['deriveBits']);
  return new Uint8Array(await subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt, info }, key, length * 8));
}

// X25519 private key from 32 raw bytes via PKCS#8 (RFC 8410 prefix).
async function x25519Private(raw) {
  const pkcs8 = new Uint8Array([...unhex('302e020100300506032b656e04220420'), ...raw]);
  return subtle.importKey('pkcs8', pkcs8, { name: 'X25519' }, true, ['deriveBits']);
}
async function x25519Public(privateKey) {
  const jwk = await subtle.exportKey('jwk', privateKey);
  return new Uint8Array(Buffer.from(jwk.x, 'base64url'));
}
async function x25519Shared(privateKey, publicRaw) {
  const pub = await subtle.importKey('raw', publicRaw, { name: 'X25519' }, false, []);
  return new Uint8Array(await subtle.deriveBits({ name: 'X25519', public: pub }, privateKey, 256));
}

const userId = '0b7c5a52-3a0e-4e8f-9d6b-2f1a4c8e9d10';

// 1. Record encryption: AES-256-GCM, AAD = recordId|recordType|userId.
const dataKey = unhex('8f3a1c5d7e9b2f4a6c8e0d1b3f5a7c9e1d3b5f7a9c0e2d4b6f8a0c2e4d6b8f0a');
const records = [];
for (const r of [
  { recordId: '6f1d2c3b-4a59-4e6f-8a7b-9c0d1e2f3a4b', recordType: 'entry', nonce: '0102030405060708090a0b0c',
    plaintext: '{"title":"Morning swim","bodyMarkdown":"The water was **cold**.","dayKey":"2026-10-14","minutesFromMidnight":435}' },
  { recordId: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', recordType: 'task', nonce: 'ffeeddccbbaa998877665544',
    plaintext: '{"title":"Post the letter","isCompleted":true,"dayKey":"2026-10-15"}' },
  { recordId: '11111111-2222-4333-8444-555555555555', recordType: 'category', nonce: '000000000000000000000001',
    plaintext: '{"name":"Travel","colorKey":"ocean","sortIndex":0}' },
]) {
  const aad = `${r.recordId}|${r.recordType}|${userId}`;
  const sealed = await aesGcm(dataKey, unhex(r.nonce), utf8(r.plaintext), utf8(aad));
  records.push({ ...r, userId, aad, ciphertextAndTag: hex(sealed) });
}

// 2. Recovery key: 128-bit, Crockford base32 (26 chars), KEK = HKDF-SHA256, DK envelope.
const recoveryBytes = unhex('5a17c3e9028b4df6a1307e5c9b2d8f41');
const recoveryString = crockford(recoveryBytes);
const kekSalt = unhex('c0ffee00112233445566778899aabbccddeeff00112233445566778899aabbcc');
const kekInfo = 'folio/recovery-kek/v1';
const kek = await hkdf(recoveryBytes, kekSalt, utf8(kekInfo));
const envelopeNonce = unhex('a0a1a2a3a4a5a6a7a8a9aaab');
const envelopeAAD = `folio/dk-envelope/v1|${userId}`;
const envelope = await aesGcm(kek, envelopeNonce, dataKey, utf8(envelopeAAD));

// 3. Crockford base32 known answers.
const base32 = ['00000000000000000000000000000000', 'ffffffffffffffffffffffffffffffff', hex(recoveryBytes)]
  .map((h) => ({ bytes: h, encoded: crockford(unhex(h)) }));

// 4. QR device-link handshake: X25519 ECDH → HKDF → AES-GCM(DK).
const newDevicePriv = unhex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
const senderPriv = unhex('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb');
const nd = await x25519Private(newDevicePriv), sd = await x25519Private(senderPriv);
const newDevicePub = await x25519Public(nd), senderPub = await x25519Public(sd);
const shared = await x25519Shared(sd, newDevicePub);
const sharedCheck = await x25519Shared(nd, senderPub);
if (hex(shared) !== hex(sharedCheck)) throw new Error('ECDH mismatch');
const requestId = '9e8d7c6b-5a49-4382-a716-f5e4d3c2b1a0';
const linkInfo = new Uint8Array([...utf8('folio/link/v1'), ...newDevicePub, ...senderPub]);
const linkKey = await hkdf(shared, utf8(requestId), linkInfo);
const linkNonce = unhex('b0b1b2b3b4b5b6b7b8b9babb');
const linkAAD = `folio/link/v1|${requestId}|${userId}`;
const linkCiphertext = await aesGcm(linkKey, linkNonce, dataKey, utf8(linkAAD));

const out = {
  $comment: 'Generated by scripts/generate-crypto-vectors.mjs (WebCrypto). Test values only — never real keys. SPEC §10.3–10.4.',
  version: 1,
  dataKey: hex(dataKey),
  records,
  recovery: {
    keyBytes: hex(recoveryBytes), keyString: recoveryString, keyDisplay: grouped(recoveryString),
    kekSalt: hex(kekSalt), kekInfo, kek: hex(kek),
    envelope: { nonce: hex(envelopeNonce), aad: envelopeAAD, ciphertextAndTag: hex(envelope) },
  },
  base32,
  link: {
    requestId, userId,
    newDevicePrivateKey: hex(newDevicePriv), newDevicePublicKey: hex(newDevicePub),
    senderPrivateKey: hex(senderPriv), senderPublicKey: hex(senderPub),
    sharedSecret: hex(shared), hkdfSalt: requestId, hkdfInfoPrefix: 'folio/link/v1',
    linkKey: hex(linkKey), nonce: hex(linkNonce), aad: linkAAD, ciphertextAndTag: hex(linkCiphertext),
  },
};
writeFileSync(new URL('../shared/crypto-vectors.json', import.meta.url), JSON.stringify(out, null, 2) + '\n');
console.log('Wrote shared/crypto-vectors.json; recovery key', out.recovery.keyDisplay);
