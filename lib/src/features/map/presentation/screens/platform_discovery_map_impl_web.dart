import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';

@JS('eval')
external JSAny? _eval(JSString code);

/// Mapbox GL JS requires a working WebGL context. Some browsers/devices can
/// still run Flutter in CPU mode while reporting WebGL version -1; attempting
/// to create the Mapbox globe in that state throws from inside Mapbox GL before
/// Flutter can recover. Probe capability first and keep the stable raster map
/// path when WebGL is disabled/unavailable.
bool _browserSupportsWebGl() {
  try {
    final result = _eval(
      r'''
      (function () {
        try {
          var canvas = document.createElement('canvas');
          var gl = canvas.getContext('webgl2', {failIfMajorPerformanceCaveat:false}) ||
                   canvas.getContext('webgl', {failIfMajorPerformanceCaveat:false}) ||
                   canvas.getContext('experimental-webgl');
          if (!gl) return false;
          var lose = gl.getExtension && gl.getExtension('WEBGL_lose_context');
          if (lose && lose.loseContext) lose.loseContext();
          return true;
        } catch (e) {
          return false;
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
  late final bool _webGlReady = _browserSupportsWebGl();
  Timer? _introWatchdog;
  bool _introWatchdogArmed = false;
  bool _introComplete = false;

  void _armIntroWatchdog() {
    if (_introWatchdogArmed || _introComplete) return;
    _introWatchdogArmed = true;
    _introWatchdog = Timer(const Duration(seconds: 7), _finishIntro);
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

        if (snapshot.data != true || !_webGlReady) {
          // The discovery renderer is Mapbox-backed raster tiles and does not
          // require WebGL. It already starts from a world view and flies into
          // the active city, so WebGL-disabled browsers keep the intended
          // experience instead of crashing on the optional spherical globe.
          return discoveryMap;
        }

        _armIntroWatchdog();

        // Prewarm the premium discovery map underneath the true Mapbox globe.
        // Its own city camera settles while the globe is visible, so removing
        // the intro reveals the finished city map instead of triggering a
        // second world-to-city animation.
        return Stack(
          fit: StackFit.expand,
          children: [
            discoveryMap,
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 480),
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
