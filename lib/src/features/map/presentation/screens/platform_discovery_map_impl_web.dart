import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';

@JS('eval')
external JSAny? _eval(JSString code);

bool _webGlobePlayedThisSession = false;

/// A real Mapbox sphere on web requires a healthy hardware WebGL2 context.
/// Never fake it with a clipped 2D map: on old/CPU-only browsers that produced
/// the blank pale circle users were seeing. Unsupported browsers now skip the
/// cinematic cleanly and go straight to the usable discovery map.
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

class _WebDiscoveryMapBootstrap extends ConsumerStatefulWidget {
  const _WebDiscoveryMapBootstrap({
    required this.onClose,
    required this.showCitiesOnOpen,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<_WebDiscoveryMapBootstrap> createState() =>
      _WebDiscoveryMapBootstrapState();
}

class _WebDiscoveryMapBootstrapState
    extends ConsumerState<_WebDiscoveryMapBootstrap> {
  late final Future<bool> _mapboxReady = MapboxRuntimeConfig.ensureConfigured();
  late final bool _globeReady = _browserSupportsMapboxGlobe();
  late final bool _playIntro;
  late final DeckAudioNotifier _audioNotifier;
  Timer? _introWatchdog;
  bool _introWatchdogArmed = false;
  bool _introComplete = false;
  bool _audioSuppressed = false;
  bool? _lastRouteActive;

  @override
  void initState() {
    super.initState();
    _audioNotifier = ref.read(deckSoundOnProvider.notifier);
    _playIntro = !_webGlobePlayedThisSession;
    if (_playIntro) _webGlobePlayedThisSession = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_lastRouteActive == active) return;
    _lastRouteActive = active;
    if (active) {
      _suppressAudio();
    } else {
      _restoreAudio();
    }
  }

  void _suppressAudio() {
    if (_audioSuppressed) return;
    _audioSuppressed = true;
    _audioNotifier.suspendTemporarily();
  }

  void _restoreAudio() {
    if (!_audioSuppressed) return;
    _audioSuppressed = false;
    _audioNotifier.resumeTemporarySound();
  }

  void _armIntroWatchdog() {
    if (_introWatchdogArmed || _introComplete) return;
    _introWatchdogArmed = true;
    _introWatchdog = Timer(const Duration(seconds: 8), _finishIntro);
  }

  void _finishIntro() {
    if (!mounted || _introComplete) return;
    _introWatchdog?.cancel();
    setState(() => _introComplete = true);
  }

  @override
  void dispose() {
    _introWatchdog?.cancel();
    _restoreAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mapboxReady,
      builder: (context, snapshot) {
        final discoveryMap = WebDiscoveryMapScreenV5(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        );

        // Do not block the actual map behind a fake loading sphere. The first
        // paint is always a real usable discovery surface.
        if (snapshot.connectionState != ConnectionState.done) {
          return discoveryMap;
        }

        if (!_playIntro) return discoveryMap;

        // No hardware WebGL2 / no Mapbox token = no 3D globe on this browser.
        // Skip it instead of displaying a 2D map clipped into a circle.
        if (snapshot.data != true || !_globeReady) {
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
