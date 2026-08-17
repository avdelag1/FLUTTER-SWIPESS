{{flutter_js}}
{{flutter_build_config}}

// Keep installed PWAs from falling back to an older cached Flutter shell after
// a new deployment. Ask any existing worker to update before loading Flutter.
(function () {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (registration) {
        registration.update().catch(function () {});
      });
    }).catch(function () {});
  }

  var isWebKit = navigator.vendor === 'Apple Computer, Inc.';
  _flutter.loader.load({
    config: {
      canvasKitVariant: 'full',
      canvasKitBaseUrl: 'canvaskit/',
      canvasKitForceCpuOnly: isWebKit,
    },
  });
})();
