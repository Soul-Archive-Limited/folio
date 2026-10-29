// The web editor's Markdown against shared/markdown-fixtures.json (SPEC §5.1), and the
// editor JSON mapping round trip. Run with `npm run test:unit`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fromMarkdown, plainText, toMarkdown } from '../src/app/lib/markdown.ts';
import { fromEditorJSON, toEditorJSON } from '../src/app/lib/editorDoc.ts';

const f = JSON.parse(readFileSync(new URL('../../shared/markdown-fixtures.json', import.meta.url), 'utf8'));

for (const c of f.canonical) {
  test(`canonical: ${c.name}`, () => {
    assert.deepEqual(fromMarkdown(c.markdown), c.document);
    assert.equal(toMarkdown(c.document), c.markdown);
    // Through the editor and back, unchanged.
    assert.equal(toMarkdown(fromEditorJSON(toEditorJSON(fromMarkdown(c.markdown)))), c.markdown);
  });
}

for (const c of f.lenient) {
  test(`lenient: ${c.name}`, () => {
    assert.deepEqual(fromMarkdown(c.markdown), c.document);
    assert.equal(toMarkdown(fromMarkdown(c.markdown)), c.serialized);
  });
}

test('nested list items flatten to lines', () => {
  const json = { type: 'doc', content: [{ type: 'bulletList', content: [{ type: 'listItem', content: [
    { type: 'paragraph', content: [{ type: 'text', text: 'a' }] },
    { type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'b' }] }] }] },
  ] }] }] };
  assert.equal(toMarkdown(fromEditorJSON(json)), '- a\n- b');
});

test('an empty editor is an empty body, and plain text drops markers', () => {
  assert.equal(toMarkdown(fromEditorJSON(toEditorJSON(fromMarkdown('')))), '');
  assert.equal(plainText('# Trip\nWe walked for **hours**.'), 'Trip\nWe walked for hours.');
});
