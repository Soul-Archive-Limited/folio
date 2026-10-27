// Hashes every inline <script> in the built pages and writes them into dist/_headers'
// Content-Security-Policy, so scripts need no 'unsafe-inline' (SPEC §11.3).
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const dist = new URL('../dist/', import.meta.url).pathname;
const placeholder = '__INLINE_SCRIPT_HASHES__';

function htmlFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return htmlFiles(path);
    return entry.name.endsWith('.html') ? [path] : [];
  });
}

const hashes = new Set();
for (const file of htmlFiles(dist)) {
  const html = readFileSync(file, 'utf8');
  for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)) {
    if (!match[1].trim()) continue;
    hashes.add(`'sha256-${createHash('sha256').update(match[1], 'utf8').digest('base64')}'`);
  }
}

const headersPath = join(dist, '_headers');
const headers = readFileSync(headersPath, 'utf8');
if (headers.split(placeholder).length !== 2) throw new Error('dist/_headers needs exactly one script-hash placeholder');
writeFileSync(headersPath, headers.replace(placeholder, [...hashes].sort().join(' ')));
console.log(`_headers: ${hashes.size} inline script hash(es)`);
