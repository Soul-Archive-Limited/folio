// Folio web app service worker (Batch J): the app shell only — the /app page and its hashed
// scripts, styles, fonts and icons — so the installed app opens offline. Nothing from /api is
// ever cached: the diary stays in memory only (SPEC §11.3), and blobs are fetched fresh.
const SHELL = 'folio-shell-v1';
const PAGE = '/app';

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(SHELL).then((cache) => cache.add(PAGE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k.startsWith('folio-shell-') && k !== SHELL).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

const isShellAsset = (path) => path.startsWith('/_astro/') || path.startsWith('/fonts/') || path.startsWith('/icons/')
  || path === '/favicon.svg' || path === '/manifest.webmanifest';

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api')) return;

  if (request.mode === 'navigate' && (url.pathname === PAGE || url.pathname.startsWith(`${PAGE}/`))) {
    // Network first, so a new version arrives at once; the cached shell when offline.
    event.respondWith(fetch(request).then((response) => {
      if (response.ok) {
        const copy = response.clone();
        caches.open(SHELL).then((cache) => cache.put(PAGE, copy));
      }
      return response;
    }).catch(() => caches.match(PAGE)));
    return;
  }

  if (isShellAsset(url.pathname)) {
    // Hashed or versioned files: cache first.
    event.respondWith(caches.match(request).then((hit) => hit || fetch(request).then((response) => {
      if (response.ok) {
        const copy = response.clone();
        caches.open(SHELL).then((cache) => cache.put(request, copy));
      }
      return response;
    })));
  }
});
