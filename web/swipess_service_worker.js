// Swipess PWA worker: freshness first.
//
// Flutter's generated cache-first worker can leave installed PWAs on an older
// main.dart.js/assets bundle after production has already moved forward. This
// worker keeps the installable PWA shell but never pins application code to an
// old release.
const SWIPESS_WORKER_VERSION = '2026-08-28.1';

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    const legacyKeys = keys.filter((key) =>
      key === 'flutter-app-cache' ||
      key === 'flutter-temp-cache' ||
      key === 'flutter-app-manifest' ||
      key.startsWith('flutter-')
    );
    const migratedFromFlutterCache = legacyKeys.length > 0;

    await Promise.all(legacyKeys.map((key) => caches.delete(key)));
    await self.clients.claim();

    // Existing installed PWAs may still be displaying a page that was loaded by
    // Flutter's old cache-first worker. Reload those clients once during the
    // migration so the current production bundle takes control immediately.
    if (migratedFromFlutterCache) {
      const windows = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      await Promise.all(windows.map(async (client) => {
        try {
          await client.navigate(client.url);
        } catch (_) {}
      }));
    }
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  const isNavigation = request.mode === 'navigate';
  const isAppShell =
    request.destination === 'script' ||
    request.destination === 'style' ||
    request.destination === 'worker' ||
    url.pathname === '/index.html' ||
    url.pathname === '/flutter_bootstrap.js' ||
    url.pathname === '/main.dart.js' ||
    url.pathname === '/version.json';

  if (!isNavigation && !isAppShell) return;

  event.respondWith((async () => {
    try {
      return await fetch(request, { cache: 'no-store' });
    } catch (_) {
      // No stale application cache is intentionally maintained. Let the normal
      // browser error surface offline rather than silently serving old code.
      return fetch(request);
    }
  })());
});
