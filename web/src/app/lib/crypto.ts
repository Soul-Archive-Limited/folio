/**
 * Web side of Folio's end-to-end encryption (SPEC §10.3–10.4), byte-for-byte compatible with
 * `FolioCrypto` on iOS and pinned by `shared/crypto-vectors.json`. WebCrypto only: AES-256-GCM,
 * HKDF-SHA256, X25519. No custom cryptography.
 */
import { concat, fromBase64, randomBytes, toBase64, utf8 } from './bytes.ts';
import { decodeBase32 } from './base32.ts';

const subtle = globalThis.crypto.subtle;
const NONCE = 12;

export type RecordType = 'entry' | 'entryPhoto' | 'task' | 'category' | 'settings' | 'photo' | 'thumb' | 'display' | 'deviceLabel';

/** The Data Key, kept as a non-extractable CryptoKey once imported. */
export type DataKey = CryptoKey;

export const importDataKey = (raw: Uint8Array, extractable = false) =>
  subtle.importKey('raw', raw as BufferSource, 'AES-GCM', extractable, ['encrypt', 'decrypt']);

export const recordAAD = (recordId: string, type: RecordType, userId: string) =>
  utf8.encode(`${recordId.toLowerCase()}|${type}|${userId.toLowerCase()}`);

export async function aesSeal(key: CryptoKey, plaintext: Uint8Array, aad: Uint8Array, nonce = randomBytes(NONCE)) {
  const sealed = new Uint8Array(await subtle.encrypt({ name: 'AES-GCM', iv: nonce as BufferSource, additionalData: aad as BufferSource }, key, plaintext as BufferSource));
  return { nonce, ciphertextAndTag: sealed };
}

export async function aesOpen(key: CryptoKey, nonce: Uint8Array, ciphertextAndTag: Uint8Array, aad: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(await subtle.decrypt({ name: 'AES-GCM', iv: nonce as BufferSource, additionalData: aad as BufferSource }, key, ciphertextAndTag as BufferSource));
}

/** A record for `POST /api/sync/push`: base64 ciphertext‖tag and nonce. */
export async function sealRecord(key: DataKey, plaintext: Uint8Array, recordId: string, type: RecordType, userId: string) {
  const { nonce, ciphertextAndTag } = await aesSeal(key, plaintext, recordAAD(recordId, type, userId));
  return { nonce: toBase64(nonce), ciphertext: toBase64(ciphertextAndTag) };
}

export async function openRecord(key: DataKey, ciphertext: string, nonce: string, recordId: string, type: RecordType, userId: string) {
  return aesOpen(key, fromBase64(nonce), fromBase64(ciphertext), recordAAD(recordId, type, userId));
}

/** A photo blob in R2: `nonce ‖ ciphertext ‖ tag` (DECISIONS 180). */
export async function sealBlob(key: DataKey, bytes: Uint8Array, photoId: string, type: 'thumb' | 'display' | 'photo', userId: string) {
  const { nonce, ciphertextAndTag } = await aesSeal(key, bytes, recordAAD(photoId, type, userId));
  return concat(nonce, ciphertextAndTag);
}

export async function openBlob(key: DataKey, combined: Uint8Array, photoId: string, type: 'thumb' | 'display' | 'photo', userId: string) {
  return aesOpen(key, combined.subarray(0, NONCE), combined.subarray(NONCE), recordAAD(photoId, type, userId));
}

// MARK: Recovery key (SPEC §10.4)

const KEK_INFO = utf8.encode('folio/recovery-kek/v1');
const envelopeAAD = (userId: string) => utf8.encode(`folio/dk-envelope/v1|${userId.toLowerCase()}`);

export async function hkdf(ikm: Uint8Array, salt: Uint8Array, info: Uint8Array): Promise<Uint8Array> {
  const base = await subtle.importKey('raw', ikm as BufferSource, 'HKDF', false, ['deriveBits']);
  return new Uint8Array(await subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt: salt as BufferSource, info: info as BufferSource }, base, 256));
}

async function kek(recoveryKey: Uint8Array, salt: Uint8Array) {
  return subtle.importKey('raw', (await hkdf(recoveryKey, salt, KEK_INFO)) as BufferSource, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

/** `version (1) ‖ salt (32) ‖ nonce (12) ‖ ciphertext ‖ tag`, base64 — 93 bytes (DECISIONS 180). */
export async function wrapWithRecoveryKey(rawDataKey: Uint8Array, recoveryKey: Uint8Array, userId: string, salt = randomBytes(32), nonce = randomBytes(NONCE)) {
  const sealed = await aesSeal(await kek(recoveryKey, salt), rawDataKey, envelopeAAD(userId), nonce);
  return toBase64(concat(new Uint8Array([1]), salt, sealed.nonce, sealed.ciphertextAndTag));
}

export class WrongRecoveryKey extends Error {}

/** Unwraps the server's envelope with a typed recovery key; the raw Data Key bytes. */
export async function unwrapWithRecoveryKey(envelope: string, typedKey: string, userId: string): Promise<Uint8Array> {
  const recovery = decodeBase32(typedKey);
  if (!recovery) throw new WrongRecoveryKey();
  const bytes = fromBase64(envelope);
  if (bytes[0] !== 1 || bytes.length < 1 + 32 + NONCE + 16) throw new WrongRecoveryKey();
  try {
    return await aesOpen(await kek(recovery, bytes.subarray(1, 33)), bytes.subarray(33, 45), bytes.subarray(45), envelopeAAD(userId));
  } catch {
    throw new WrongRecoveryKey();
  }
}

// MARK: Link with QR (SPEC §10.4)

const LINK_INFO = utf8.encode('folio/link/v1');
const linkAAD = (requestId: string, userId: string) => utf8.encode(`folio/link/v1|${requestId}|${userId.toLowerCase()}`);

export async function x25519KeyPair(): Promise<CryptoKeyPair> {
  return (await subtle.generateKey({ name: 'X25519' }, false, ['deriveBits'])) as CryptoKeyPair;
}

export const exportPublicKey = async (key: CryptoKey) => new Uint8Array(await subtle.exportKey('raw', key));

/** HKDF(ECDH, salt = request id, info = prefix ‖ new device key ‖ sender key) → AES key bytes. */
export async function linkKeyBytes(privateKey: CryptoKey, peerPublic: Uint8Array, newDevicePublic: Uint8Array, senderPublic: Uint8Array, requestId: string) {
  const peer = await subtle.importKey('raw', peerPublic as BufferSource, { name: 'X25519' }, false, []);
  const shared = new Uint8Array(await subtle.deriveBits({ name: 'X25519', public: peer }, privateKey, 256));
  return hkdf(shared, utf8.encode(requestId), concat(LINK_INFO, newDevicePublic, senderPublic));
}

/** The new device opens the Data Key the approving iPhone sealed to its QR key. */
export async function receiveLinkedKey(pair: CryptoKeyPair, reply: { senderPublicKey: string; envelope: string; nonce: string }, requestId: string, userId: string) {
  const ownPublic = await exportPublicKey(pair.publicKey);
  const sender = fromBase64(reply.senderPublicKey);
  const keyBytes = await linkKeyBytes(pair.privateKey, sender, ownPublic, sender, requestId);
  const key = await subtle.importKey('raw', keyBytes as BufferSource, 'AES-GCM', false, ['decrypt']);
  return aesOpen(key, fromBase64(reply.nonce), fromBase64(reply.envelope), linkAAD(requestId, userId));
}

export { linkAAD };
