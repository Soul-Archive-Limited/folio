// Local stand-in for Cloudflare Pages + the Worker route (Batch F): serves web/dist with
// _headers (Pages' merge rule: unset, then set/append), the /app/* rewrite, pretty URLs and
// gzip, and proxies /api (HTTP and WebSocket) to `wrangler dev` on 8787, presenting the
// production Origin so the Worker's CSRF check passes. Local testing only.
//   node scripts/web-local-server.mjs web/dist 8788
import { createServer, request as httpRequest } from 'node:http';
import { connect } from 'node:net';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';
import { gzipSync } from 'node:zlib';

const dist = process.argv[2];
const port = Number(process.argv[3] ?? 8788);
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.woff2': 'font/woff2', '.xml': 'application/xml', '.txt': 'text/plain' };

function rules() {
  const out = [];
  let rule = null;
  for (const line of readFileSync(join(dist, '_headers'), 'utf8').split('\n')) {
    if (!line.trim() || line.trim().startsWith('#')) continue;
    if (!/^\s/.test(line)) { rule = { path: line.trim(), set: [], unset: [] }; out.push(rule); continue; }
    const t = line.trim();
    if (t.startsWith('! ')) rule.unset.push(t.slice(2).toLowerCase());
    else { const i = t.indexOf(':'); rule.set.push([t.slice(0, i).toLowerCase(), t.slice(i + 1).trim()]); }
  }
  return out;
}
const match = (pattern, path) => new RegExp('^' + pattern.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$').test(path);

function headersFor(path) {
  const h = new Map();
  const seen = new Set();
  for (const r of rules()) {
    if (!match(r.path, path)) continue;
    r.unset.forEach((k) => h.delete(k));
    for (const [k, v] of r.set) {
      if (seen.has(k) && h.has(k)) h.set(k, `${h.get(k)}, ${v}`); else { h.set(k, v); seen.add(k); }
    }
  }
  h.delete('strict-transport-security'); // http on localhost
  h.set('content-security-policy', (h.get('content-security-policy') ?? '').replace('upgrade-insecure-requests', '').replace('wss://folio.devilsense.com', `ws://localhost:${port}`));
  return h;
}

function resolve(path) {
  if (path.startsWith('/app/')) path = '/app';
  const candidates = path.endsWith('/') ? [path + 'index.html'] : [path, path + '.html'];
  for (const c of candidates) { const f = join(dist, c); if (existsSync(f) && statSync(f).isFile()) return f; }
  return null;
}

const server = createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname.startsWith('/api/')) {
    if (req.headers.origin) req.headers.origin = 'https://folio.devilsense.com';
    const upstream = httpRequest({ host: '127.0.0.1', port: 8787, method: req.method, path: req.url, headers: req.headers }, (r) => {
      res.writeHead(r.statusCode, r.headers);
      r.pipe(res);
    });
    upstream.on('error', () => { res.writeHead(502); res.end(); });
    req.pipe(upstream);
    return;
  }
  const file = resolve(url.pathname);
  const status = file ? 200 : 404;
  const body = readFileSync(file ?? join(dist, '404.html'));
  const h = headersFor(url.pathname);
  h.set('content-type', types[extname(file ?? '.html')] ?? 'application/octet-stream');
  let out = body;
  if (/gzip/.test(req.headers['accept-encoding'] ?? '') && /text|javascript|svg|xml|css/.test(h.get('content-type'))) { out = gzipSync(body); h.set('content-encoding', 'gzip'); }
  res.writeHead(status, Object.fromEntries(h));
  res.end(out);
});

server.on('upgrade', (req, socket, head) => {
  if (req.headers.origin) req.headers.origin = 'https://folio.devilsense.com';
  const upstream = connect(8787, '127.0.0.1', () => {
    upstream.write(`${req.method} ${req.url} HTTP/1.1\r\n` + Object.entries(req.headers).map(([k, v]) => `${k}: ${v}`).join('\r\n') + '\r\n\r\n');
    upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });
  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
});
server.listen(port, 'localhost', () => console.log(`serving ${dist} on http://localhost:${port}`));
