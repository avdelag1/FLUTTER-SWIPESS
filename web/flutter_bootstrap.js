{{flutter_js}}
{{flutter_build_config}}

// Safari / WebKit: no service worker + full CanvasKit (not chromium variant).
// Stale SW + WebGL context loss = white page on Safari while Chrome still works.
(function () {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (r) { r.unregister(); });
    });
  }

  _flutter.loader.load({
    config: {
      canvasKitVariant: 'full',
      canvasKitBaseUrl: 'canvaskit/',
    },
    onEntrypointLoaded: async function (engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine({
        canvasKitVariant: 'full',
      });
      await appRunner.runApp();
    },
  });
})();
