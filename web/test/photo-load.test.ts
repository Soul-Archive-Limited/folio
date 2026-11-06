// Photo views (Batch K): a card whose photo was replaced kept showing the old one.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { photoLoadFor } from '../src/app/lib/photo-load.ts';

test('a different photo starts fresh, at its best rendition', () => {
  assert.deepEqual(photoLoadFor({ id: 'old', step: 1, attempt: 2 }, 'new'), { id: 'new', step: 0, attempt: 0 });
});

test('the same photo keeps its fallback step and retries', () => {
  const load = { id: 'p', step: 1, attempt: 1 };
  assert.equal(photoLoadFor(load, 'p'), load);
});
