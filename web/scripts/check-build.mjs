// `npm test`: checks the built site (dist/) against SPEC §11.2–11.3 and the Batch D rules.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';

const dist = (p) => new URL(`../dist/${p}`, import.meta.url);
const read = (p) => readFileSync(dist(p), 'utf8');
const pages = ['index', 'privacy', 'terms', 'support', 'open-source', 'changelog', 'delete-account', '404'];
let checks = 0;
const check = (fn, label) => { fn(); checks += 1; process.stdout.write(`✓ ${label}\n`); };

const headers = read('_headers');
check(() => {
  assert.ok(!headers.includes('__INLINE_SCRIPT_HASHES__'), 'hashes filled in');
  for (const h of ['Content-Security-Policy', 'Strict-Transport-Security', 'X-Content-Type-Options: nosniff',
    'Referrer-Policy: strict-origin-when-cross-origin', 'Permissions-Policy: camera=(), microphone=(), geolocation=()',
    'Cross-Origin-Opener-Policy: same-origin', "frame-ancestors 'none'"]) assert.ok(headers.includes(h), h);
  const csp = headers.split('\n').find((line) => line.trim().startsWith('Content-Security-Policy:')) ?? '';
  assert.ok(!/script-src[^;]*'unsafe-inline'/.test(csp), 'no unsafe-inline scripts');
  assert.match(csp, /script-src 'self' 'sha256-/);
}, '_headers has the §11.3 security headers');

for (const page of pages) {
  const html = read(`${page}.html`);
  check(() => {
    assert.match(html, /<title>[^<]+<\/title>/);
    assert.match(html, /<meta name="description" content="[^"]{30,}"/);
    assert.match(html, /property="og:image"/);
    assert.match(html, /rel="icon"/);
    assert.match(html, /Company no\. 16186654/);
    assert.ok(!/google-analytics|gtag\(|plausible|document\.cookie|<form/i.test(html), 'no analytics, cookies or forms');
    for (const m of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)) {
      if (!m[1].trim()) continue;
      const hash = `'sha256-${createHash('sha256').update(m[1], 'utf8').digest('base64')}'`;
      assert.ok(headers.includes(hash), `inline script in ${page} is hashed`);
    }
  }, `${page}: title, description, OG, footer, no tracking, scripts hashed`);
}

check(() => {
  const config = readFileSync(new URL('../src/config/site.ts', import.meta.url), 'utf8');
  const empty = (key) => new RegExp(`${key}: ''`).test(config);
  const home = read('index.html');
  if (empty('testflightUrl')) assert.ok(!/Join the TestFlight/.test(home), 'no TestFlight button without a URL');
  if (empty('appStoreUrl')) assert.ok(!/App Store/.test(home.replace(/<title>.*<\/title>/, '')) || !/apps\.apple\.com/.test(home));
  if (/webAppLive: false/.test(config)) assert.ok(!/href="\/app"/.test(home), 'no web app link before it is live');
  if (/webAppLive: true/.test(config)) {
    assert.match(home, /href="\/app"[^>]*>Open in browser/, 'hero opens the web app');
    assert.match(home, /href="\/app">Open web app/, 'nav opens the web app');
  } else if (empty('testflightUrl') && empty('appStoreUrl')) {
    assert.match(home, /View the source on GitHub/);
    assert.match(home, /How your privacy works/);
  }
}, 'CTAs render only when configured');

check(() => {
  const robots = read('robots.txt');
  assert.match(robots, /Disallow: \/app/);
  assert.match(robots, /Disallow: \/api/);
  assert.ok(existsSync(dist('sitemap-index.xml')));
  assert.ok(existsSync(dist('og.png')), 'OG image');
}, 'robots.txt, sitemap and OG image');

check(() => {
  const tokens = JSON.parse(readFileSync(new URL('../../shared/design-tokens.json', import.meta.url), 'utf8'));
  const css = readFileSync(new URL('../src/styles/tokens.css', import.meta.url), 'utf8');
  assert.ok(css.includes(`--ember: ${tokens.colors.ember.light.toLowerCase()}`));
  assert.ok(css.includes(`--ember: ${tokens.colors.ember.dark.toLowerCase()}`));
}, 'tokens.css matches shared/design-tokens.json');

check(() => {
  const legal = read('privacy.html') + read('terms.html');
  assert.match(read('privacy.html'), /Last updated/);
  assert.match(read('terms.html'), /Last updated/);
  assert.match(legal, /Recently Deleted/);
  assert.match(legal, /30 days/);
  assert.match(read('support.html'), /Can you read my diary\?/);
  assert.match(read('support.html'), /What happens when I delete something\?/);
}, 'legal pages and FAQ content');

// Fix 10 (Batch E): white text on `emberStrong` and `emberText` on the background pass WCAG AA in both modes.
check(() => {
  const tokens = JSON.parse(readFileSync(new URL('../../shared/design-tokens.json', import.meta.url), 'utf8')).colors;
  const lum = (hex) => {
    const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map((v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  };
  const ratio = (a, b) => (Math.max(lum(a), lum(b)) + 0.05) / (Math.min(lum(a), lum(b)) + 0.05);
  for (const mode of ['light', 'dark']) {
    assert.ok(ratio(tokens.emberStrong[mode], '#FFFFFF') >= 4.5, `white on emberStrong (${mode})`);
    assert.ok(ratio(tokens.emberText[mode], tokens.bg[mode]) >= 4.5, `emberText on bg (${mode})`);
    assert.ok(ratio(tokens.emberText[mode], tokens.bgElevated[mode]) >= 4.5, `emberText on bgElevated (${mode})`);
  }
}, 'ember text and fills pass WCAG AA (4.5:1)');

// Phase 12 (Batch F): the web app's page, routing and policy.
check(() => {
  const html = read('app.html');
  assert.match(html, /<meta name="robots" content="noindex"/);
  assert.doesNotMatch(html, /google-analytics|gtag|plausible|document\.cookie/);
  assert.match(readFileSync(new URL('../dist/_redirects', import.meta.url), 'utf8'), /^\/app\/\* \/app 200$/m);
  const headers = readFileSync(new URL('../dist/_headers', import.meta.url), 'utf8');
  for (const path of ['/app', '/app/*']) {
    const block = headers.split(/\n(?=\S)/).find((b) => b.startsWith(`${path}\n`));
    assert.ok(block, `${path} rule`);
    assert.match(block, /^\s+! Content-Security-Policy$/m, `${path} detaches the site CSP`);
    assert.match(block, /script-src 'self' 'sha256-[^']+'.* https:\/\/challenges\.cloudflare\.com;/, `${path} script-src`);
    assert.match(block, /frame-src https:\/\/challenges\.cloudflare\.com;/);
    assert.match(block, /frame-ancestors 'none'/);
    assert.match(block, /Cache-Control: no-store/);
    assert.doesNotMatch(block, /unsafe-eval|__INLINE_SCRIPT_HASHES__/);
  }
  assert.doesNotMatch(readFileSync(new URL('../dist/sitemap-0.xml', import.meta.url), 'utf8'), /\/app/);
}, 'web app: noindex, rewrite, its own CSP with Turnstile, not in the sitemap, no tracking');

console.log(`\n${checks} checks passed`);
