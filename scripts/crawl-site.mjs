// Part of the Batch L release checks: node scripts/crawl-site.mjs https://folio.devilsense.com
// node crawl.mjs <base> — follows every same-origin link; checks pages, images, srcsets, OG images,
// icons, scripts and stylesheets; HEADs external links; flags placeholder words.
const base = process.argv[2];
const origin = new URL(base).origin;
const pages = new Set(['/']), done = new Set(), assets = new Map(), external = new Map(), problems = [];
const bad = /coming soon|lorem ipsum|placeholder text|\bTODO\b|\bTBD\b|fake review|★★★★★/i;
async function status(url, method = 'HEAD') {
  try { const r = await fetch(url, { method, redirect: 'manual', headers: { 'user-agent': 'Mozilla/5.0 FolioLinkCheck' } }); return r.status; } catch (e) { return 'ERR ' + e.message.slice(0, 40); }
}
while (true) {
  const next = [...pages].find((p) => !done.has(p)); if (!next) break; done.add(next);
  const res = await fetch(origin + next, { redirect: 'manual' });
  if (res.status >= 300) { problems.push(`page ${next} → ${res.status}`); continue; }
  const html = await res.text();
  const text = html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/g, '').replace(/<[^>]+>/g, ' ');
  const m = text.match(bad); if (m && !next.startsWith('/app')) problems.push(`page ${next}: placeholder word "${m[0]}"`);
  for (const [, attr, val] of html.matchAll(/\s(href|src|srcset|content)="([^"]+)"/g)) {
    const urls = attr === 'srcset' ? val.split(',').map((s) => s.trim().split(' ')[0]) : [val];
    for (const raw of urls) {
      if (!raw || raw.startsWith('#') || raw.startsWith('mailto:') || raw.startsWith('data:') || raw.startsWith('tel:')) continue;
      if (attr === 'content' && !/^https?:\/\/|^\//.test(raw)) continue;
      let u; try { u = new URL(raw, origin + next); } catch { continue; }
      if (u.origin === origin || u.origin === 'https://folio.devilsense.com') {
        const path = u.pathname;
        const isPage = attr === 'href' && !/\.[a-z0-9]{2,5}$/i.test(path) && !path.startsWith('/api');
        if (isPage) pages.add(path.replace(/\/$/, '') || '/'); else if (!path.startsWith('/api')) assets.set(path, next);
      } else if (/^https?:/.test(u.protocol)) external.set(u.href, next);
    }
  }
}
for (const [path, from] of assets) { const s = await status(origin + path, 'GET'); if (s !== 200) problems.push(`asset ${path} (on ${from}) → ${s}`); }
for (const [href, from] of external) { let s = await status(href); if (s === 405 || s === 403) s = await status(href, 'GET'); if (typeof s !== 'number' || s >= 400) problems.push(`external ${href} (on ${from}) → ${s}`); }
console.log(`pages ${done.size}, assets ${assets.size}, external ${external.size}`);
console.log([...external.keys()].join('\n'));
console.log(problems.length ? 'PROBLEMS:\n' + problems.join('\n') : 'no broken links, images or placeholder text');
