import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';

@JS('eval')
external JSAny? _eval(JSString code);

bool _webGlobePlayedThisSession = false;

/// The spherical Mapbox intro is optional on web and must never compromise the
/// normal discovery map. Require a healthy hardware WebGL2 context up front.
bool _browserSupportsMapboxGlobe() {
  try {
    final result = _eval(
      r'''
      (function () {
        var gl = null;
        try {
          var canvas = document.createElement('canvas');
          gl = canvas.getContext('webgl2', {
            failIfMajorPerformanceCaveat: true,
            antialias: true,
            alpha: true,
            depth: true,
            stencil: true,
            powerPreference: 'high-performance'
          });
          if (!gl) return false;
          try {
            var debug = gl.getExtension('WEBGL_debug_renderer_info');
            if (debug) {
              var renderer = String(
                gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) || ''
              ).toLowerCase();
              var blocked = [
                'swiftshader',
                'software',
                'llvmpipe',
                'microsoft basic render'
              ];
              for (var i = 0; i < blocked.length; i++) {
                if (renderer.indexOf(blocked[i]) !== -1) return false;
              }
            }
          } catch (_) {}
          return true;
        } catch (_) {
          return false;
        } finally {
          try {
            if (gl) {
              var lose = gl.getExtension('WEBGL_lose_context');
              if (lose && lose.loseContext) lose.loseContext();
            }
          } catch (_) {}
        }
      })()
      '''
          .toJS,
    ) as JSBoolean;
    return result.toDart;
  } catch (_) {
    return false;
  }
}

Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return _WebDiscoveryMapBootstrap(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}

class _WebDiscoveryMapBootstrap extends StatefulWidget {
  const _WebDiscoveryMapBootstrap({
    required this.onClose,
    required this.showCitiesOnOpen,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  State<_WebDiscoveryMapBootstrap> createState() =>
      _WebDiscoveryMapBootstrapState();
}

class _WebDiscoveryMapBootstrapState extends State<_WebDiscoveryMapBootstrap> {
  late final Future<bool> _mapboxReady = MapboxRuntimeConfig.ensureConfigured();
  late final bool _globeReady = _browserSupportsMapboxGlobe();
  late final bool _playIntro;
  Timer? _introWatchdog;
  bool _introWatchdogArmed = false;
  bool _introComplete = false;

  @override
  void initState() {
    super.initState();
    _playIntro = !_webGlobePlayedThisSession;
    if (_playIntro) _webGlobePlayedThisSession = true;
  }

  void _armIntroWatchdog() {
    if (_introWatchdogArmed || _introComplete) return;
    _introWatchdogArmed = true;
    _introWatchdog = Timer(const Duration(seconds: 10), _finishIntro);
  }

  void _finishIntro() {
    if (!mounted || _introComplete) return;
    _introWatchdog?.cancel();
    setState(() => _introComplete = true);
  }

  @override
  void dispose() {
    _introWatchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mapboxReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFFF5F8FA),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black87,
                ),
              ),
            ),
          );
        }

        final discoveryMap = WebDiscoveryMapScreenV5(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        );

        // Re-entering Map later in the same app session goes straight back to
        // the live map. The cinematic world intro is an opening moment, not a
        // repeated interruption.
        if (!_playIntro) return discoveryMap;

        if (snapshot.data != true || !_globeReady) {
          // CPU-only/unsupported browsers use the Flutter-rendered world-to-city
          // fallback inside the discovery map instead of creating a broken
          // Mapbox GL surface.
          return discoveryMap;
        }

        _armIntroWatchdog();

        return Stack(
          fit: StackFit.expand,
          children: [
            discoveryMap,
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _introComplete
                    ? const SizedBox.expand(
                        key: ValueKey('mapbox-world-intro-complete'),
                      )
                    : MapboxWorldIntroScreen(
                        key: const ValueKey('mapbox-world-intro'),
                        onComplete: _finishIntro,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
