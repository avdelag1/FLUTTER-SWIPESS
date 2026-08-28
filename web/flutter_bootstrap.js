{{flutter_js}}
{{flutter_build_config}}

// Swipess owns the web/PWA update policy instead of Flutter's cache-first
// generated worker. The custom worker is network-first for app-shell files, so
// installed PWAs pick up the same main-branch build as the normal website.
(function () {
  var isWebKit = navigator.vendor === 'Apple Computer, Inc.';
  var hadController = !!navigator.serviceWorker?.controller;
  var reloadingForUpdate = false;

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('controllerchange', function () {
      // Do not reload on a user's first-ever worker install. On a real update,
      // reload once so the newly activated shell is visible immediately.
      if (!hadController) {
        hadController = true;
        return;
      }
      if (reloadingForUpdate) return;
      reloadingForUpdate = true;
      window.location.reload();
    });

    navigator.serviceWorker
      .register('/flutter_service_worker.js', { updateViaCache: 'none' })
      .then(function (registration) {
        if (registration.waiting) {
          registration.waiting.postMessage({ type: 'SKIP_WAITING' });
        }
        return registration.update();
      })
      .catch(function () {
        // A service-worker failure must never block Flutter from starting.
      });
  }

  _flutter.loader.load({
    config: {
      canvasKitVariant: 'full',
      canvasKitBaseUrl: 'canvaskit/',
      canvasKitForceCpuOnly: isWebKit,
    },
  });
})();
