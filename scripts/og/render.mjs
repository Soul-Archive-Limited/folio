// Renders the website's OG images (web/public/og/<page>.png, 1200 × 630) from scripts/og/pages.json
// with the shared tokens, the brand mark and the site's own app screenshots (Batch K).
// Needs playwright-core and a Chromium browser (Brave on this Mac), installed outside the repo:
//   node scripts/og/render.mjs <path to playwright-core> [browser executable]
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = resolve(new URL('../..', import.meta.url).pathname);
const [pwPath, browser = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'] = process.argv.slice(2);
const { chromium } = await import(pathToFileURL(join(resolve(pwPath), 'index.mjs')).href);
const tokens = JSON.parse(readFileSync(join(root, 'shared/design-tokens.json'), 'utf8')).colors;
const pages = JSON.parse(readFileSync(join(root, 'scripts/og/pages.json'), 'utf8'));
const mark = readFileSync(join(root, 'shared/brand/folio-tile.svg'), 'utf8');
const pub = pathToFileURL(join(root, 'web/public')).href;

const html = (p) => `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face { font-family: 'Instrument Serif'; src: url(${pub}/fonts/instrument-serif-latin-400-normal.woff2); }
@font-face { font-family: 'Instrument Serif'; font-style: italic; src: url(${pub}/fonts/instrument-serif-latin-400-italic.woff2); }
* { margin: 0; box-sizing: border-box; }
body { width: 1200px; height: 630px; overflow: hidden; background: ${tokens.bg.light}; font-family: -apple-system, system-ui, sans-serif; color: ${tokens.ink.light}; position: relative; }
.aura { position: absolute; border-radius: 50%; filter: blur(90px); opacity: .55; }
.brand { position: absolute; left: 80px; top: 62px; display: flex; align-items: center; gap: 16px; font: 400 40px 'Instrument Serif'; }
.brand svg { width: 52px; height: 52px; }
h1 { position: absolute; left: 76px; top: 212px; width: 680px; font: 400 104px/1 'Instrument Serif'; letter-spacing: -2px; }
h1 em { color: ${tokens.accentText.light}; }
p { position: absolute; left: 80px; top: 452px; width: 600px; font-size: 28px; line-height: 1.3; color: rgb(23 22 28 / .68); }
.phone { position: absolute; right: 70px; top: 40px; width: 290px; height: 600px; border-radius: 52px; background: #1b1b20; padding: 11px; transform: rotate(6deg); box-shadow: 0 40px 80px rgb(40 50 140 / .25); }
.phone img { width: 100%; height: 100%; object-fit: cover; object-position: top; border-radius: 42px; }
</style></head><body>
<div class="aura" style="width:520px;height:520px;left:620px;top:-160px;background:${tokens.aura1.light}"></div>
<div class="aura" style="width:420px;height:420px;left:-120px;top:380px;background:${tokens.aura3.light}"></div>
<div class="aura" style="width:380px;height:380px;left:980px;top:360px;background:${tokens.aura2.light}"></div>
<div class="brand">${mark}<span>Folio</span></div>
<h1>${p.before} <em>${p.accent}</em></h1>
<p>${p.line}</p>
<div class="phone"><img src="${pub}/img/app/${p.shot}.webp"></div>
</body></html>`;

const dir = mkdtempSync(join(tmpdir(), 'folio-og-'));
const b = await chromium.launch({ executablePath: browser });
const page = await b.newPage({ viewport: { width: 1200, height: 630 } });
for (const p of pages) {
  const file = join(dir, `${p.file}.html`);
  writeFileSync(file, html(p));
  await page.goto(pathToFileURL(file).href);
  await page.evaluate(async () => { await document.fonts.ready; await Promise.all([...document.images].map((i) => i.decode())); });
  await page.screenshot({ path: join(root, `web/public/og/${p.file}.png`) });
  console.log(`og/${p.file}.png`);
}
await b.close();
