// WebCrypto against shared/crypto-vectors.json (SPEC §10.3): the web app must agree with
// FolioCrypto on iOS byte for byte. Run with `npm run test:unit`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fromHex, toBase64, toBase64Url, toHex, utf8 } from '../src/app/lib/bytes.ts';
import { decodeBase32, encodeBase32, recoveryKeyLines } from '../src/app/lib/base32.ts';
import {
  aesOpen, aesSeal, hkdf, importDataKey, linkKeyBytes, openRecord, receiveLinkedKey, recordAAD, sealBlob, openBlob,
  unwrapWithRecoveryKey, wrapWithRecoveryKey, WrongRecoveryKey, type RecordType,
} from '../src/app/lib/crypto.ts';

const v = JSON.parse(readFileSync(new URL('../../shared/crypto-vectors.json', import.meta.url), 'utf8'));

test('records seal and open exactly like iOS', async () => {
  const key = await importDataKey(fromHex(v.dataKey));
  for (const r of v.records) {
    const aad = recordAAD(r.recordId, r.recordType as RecordType, r.userId);
    assert.equal(new TextDecoder().decode(aad), r.aad);
    const sealed = await aesSeal(key, utf8.encode(r.plaintext), aad, fromHex(r.nonce));
    assert.equal(toHex(sealed.ciphertextAndTag), r.ciphertextAndTag, r.recordType);
    const opened = await openRecord(key, toBase64(sealed.ciphertextAndTag), toBase64(fromHex(r.nonce)), r.recordId.toUpperCase(), r.recordType, r.userId);
    assert.equal(new TextDecoder().decode(opened), r.plaintext);
  }
});

test('a tampered record or the wrong id fails', async () => {
  const key = await importDataKey(fromHex(v.dataKey));
  const r = v.records[0];
  const bad = fromHex(r.ciphertextAndTag);
  bad[0] ^= 1;
  await assert.rejects(aesOpen(key, fromHex(r.nonce), bad, recordAAD(r.recordId, r.recordType, r.userId)));
  await assert.rejects(aesOpen(key, fromHex(r.nonce), fromHex(r.ciphertextAndTag), recordAAD(crypto.randomUUID(), r.recordType, r.userId)));
});

test('photo blobs round-trip as nonce ‖ ciphertext ‖ tag', async () => {
  const key = await importDataKey(fromHex(v.dataKey));
  const id = crypto.randomUUID().toUpperCase();
  const blob = await sealBlob(key, new Uint8Array([1, 2, 3]), id, 'thumb', v.recovery.envelope.aad.split('|')[1]);
  assert.equal(blob.length, 12 + 3 + 16);
  assert.deepEqual([...(await openBlob(key, blob, id.toLowerCase(), 'thumb', v.recovery.envelope.aad.split('|')[1]))], [1, 2, 3]);
});

test('Crockford base32 and the two-line display', () => {
  for (const b of v.base32) {
    assert.equal(encodeBase32(fromHex(b.bytes)), b.encoded);
    assert.equal(toHex(decodeBase32(b.encoded)!), b.bytes);
  }
  assert.equal(recoveryKeyLines(v.recovery.keyString).join('-'), v.recovery.keyDisplay);
  assert.equal(toHex(decodeBase32(v.recovery.keyDisplay.toLowerCase().replace(/-/g, ' '))!), v.recovery.keyBytes);
  assert.equal(toHex(decodeBase32('B8BW7T82HD6ZD89GFSE9PBCF84'.replace(/0/g, 'O'))!), v.recovery.keyBytes);
  assert.equal(decodeBase32('too short'), null);
});

test('recovery envelope: KEK, wrap and unwrap match iOS', async () => {
  const rec = v.recovery;
  assert.equal(toHex(await hkdf(fromHex(rec.keyBytes), fromHex(rec.kekSalt), utf8.encode(rec.kekInfo))), rec.kek);
  const userId = rec.envelope.aad.split('|')[1];
  const envelope = await wrapWithRecoveryKey(fromHex(v.dataKey), fromHex(rec.keyBytes), userId, fromHex(rec.kekSalt), fromHex(rec.envelope.nonce));
  const bytes = Uint8Array.from(atob(envelope), (c) => c.charCodeAt(0));
  assert.equal(bytes.length, 93);
  assert.equal(toHex(bytes.subarray(45)), rec.envelope.ciphertextAndTag);
  assert.equal(toHex(await unwrapWithRecoveryKey(envelope, rec.keyDisplay, userId)), v.dataKey);
  await assert.rejects(unwrapWithRecoveryKey(envelope, '0'.repeat(26), userId), WrongRecoveryKey);
});

test('QR link: X25519 + HKDF matches iOS, and the new device opens the Data Key', async () => {
  const l = v.link;
  const jwk = (priv: string, pub: string) => ({ kty: 'OKP', crv: 'X25519', d: toBase64Url(fromHex(priv)), x: toBase64Url(fromHex(pub)) });
  const sub = crypto.subtle;
  const newPriv = await sub.importKey('jwk', jwk(l.newDevicePrivateKey, l.newDevicePublicKey), { name: 'X25519' }, false, ['deriveBits']);
  const newPub = await sub.importKey('raw', fromHex(l.newDevicePublicKey), { name: 'X25519' }, true, []);
  const key = await linkKeyBytes(newPriv, fromHex(l.senderPublicKey), fromHex(l.newDevicePublicKey), fromHex(l.senderPublicKey), l.requestId);
  assert.equal(toHex(key), l.linkKey);
  const reply = { senderPublicKey: toBase64(fromHex(l.senderPublicKey)), envelope: toBase64(fromHex(l.ciphertextAndTag)), nonce: toBase64(fromHex(l.nonce)) };
  const dk = await receiveLinkedKey({ privateKey: newPriv, publicKey: newPub }, reply, l.requestId, l.userId);
  assert.equal(toHex(dk), v.dataKey);
});
