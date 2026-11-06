// The web export's zip writer (Batch L): a valid stored archive that unzip can read.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { crc32, zip } from '../src/app/lib/zip.ts';

test('crc32 of "hello" is 0x3610a686', () => assert.equal(crc32(new TextEncoder().encode('hello')), 0x3610a686));
test('unzip lists and verifies the files', async () => {
  const blob = zip([{ name: 'Folio Export.json', data: new TextEncoder().encode('{"a":1}') }, { name: 'Folio Photos/2026-10-27 1.jpg', data: new Uint8Array([0xff, 0xd8, 1, 2, 3]) }]);
  const dir = mkdtempSync(join(tmpdir(), 'folio-zip-'));
  const file = join(dir, 'e.zip');
  writeFileSync(file, new Uint8Array(await blob.arrayBuffer()));
  const out = execFileSync('unzip', ['-t', file]).toString();
  assert.match(out, /No errors detected/);
  assert.match(out, /Folio Photos\/2026-10-27 1\.jpg/);
});
