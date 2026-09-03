// Swipess PWA worker: freshness first.
//
// Flutter's generated cache-first worker can leave installed PWAs on an older
// main.dart.js/assets bundle after production has already moved forward. This
// worker keeps the installable PWA shell but never pins application code to an
// old release.
const SWIPESS_WORKER_VERSION = '2026-09-03.2';
const SWIPESS_SHARE_CACHE = 'swipess-share-inbox-v1';

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

async function acceptIncomingShare(request) {
  const form = await request.formData();
  const files = form.getAll('media').filter((entry) =>
    entry instanceof File &&
    entry.size > 0 &&
    (entry.type.startsWith('image/') || entry.type.startsWith('video/'))
  ).slice(0, 32);

  if (files.length === 0) {
    return Response.redirect('/client/dashboard', 303);
  }

  // Keep only the latest not-yet-consumed share. This prevents a long-lived PWA
  // cache from accumulating private gallery media across sessions.
  await caches.delete(SWIPESS_SHARE_CACHE);
  const cache = await caches.open(SWIPESS_SHARE_CACHE);
  const session = self.crypto?.randomUUID?.() ||
    `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const manifest = [];

  for (let index = 0; index < files.length; index += 1) {
    const file = files[index];
    const resourcePath = `/__swipess_share/${encodeURIComponent(session)}/${index}`;
    const resourceUrl = new URL(resourcePath, self.location.origin).toString();
    await cache.put(
      new Request(resourceUrl),
      new Response(file, {
        headers: {
          'Content-Type': file.type || 'application/octet-stream',
          'Cache-Control': 'no-store',
        },
      }),
    );
    manifest.push({
      url: resourcePath,
      name: file.name || `shared-${index}`,
      type: file.type || '',
      size: file.size,
    });
  }

  const manifestPath = `/__swipess_share/${encodeURIComponent(session)}/manifest.json`;
  await cache.put(
    new Request(new URL(manifestPath, self.location.origin).toString()),
    new Response(JSON.stringify({ files: manifest }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    }),
  );

  return Response.redirect(
    `/client/dashboard?share_session=${encodeURIComponent(session)}`,
    303,
  );
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.method === 'POST' && url.pathname === '/share-target') {
    event.respondWith(acceptIncomingShare(request));
    return;
  }

  if (request.method === 'GET' && url.pathname.startsWith('/__swipess_share/')) {
    event.respondWith((async () => {
      const cache = await caches.open(SWIPESS_SHARE_CACHE);
      return (await cache.match(request)) || new Response('Not found', { status: 404 });
    })());
    return;
  }

  if (request.method !== 'GET') return;

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
