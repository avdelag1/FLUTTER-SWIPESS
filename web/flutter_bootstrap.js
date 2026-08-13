{{flutter_js}}
{{flutter_build_config}}

// Safari/WebKit loses WebGL → white/black blank page. Force CPU CanvasKit there.
// Chrome keeps GPU. Do not pass onEntrypointLoaded or `config` is ignored.
(function () {
  var isWebKit = navigator.vendor === 'Apple Computer, Inc.';
  _flutter.loader.load({
    config: {
      canvasKitVariant: 'full',
      canvasKitBaseUrl: 'canvaskit/',
      canvasKitForceCpuOnly: isWebKit,
    },
  });
})();
