import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_mapbox_v3.dart';

@JS('eval')
external JSAny? _eval(JSString code);

/// Prefer the persistent Mapbox GL surface whenever the browser has a healthy
/// hardware WebGL2 context. The previous implementation used Mapbox only for a
/// cinematic intro and then deliberately swapped to FlutterMap, which is the
/// exact reason the world looked 3D and the actual discovery map became 2D.
bool _browserSupportsPersistentMapbox() {
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
  late final bool _hardwareReady = _browserSupportsPersistentMapbox();
  late final DeckAudioNotifier _audioNotifier;
  bool _audioSuppressed = false;
  bool? _lastRouteActive;

  @override
  void initState() {
    super.initState();
    _audioNotifier = ref.read(deckSoundOnProvider.notifier);
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

  @override
  void dispose() {
    _restoreAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mapboxReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data == true &&
            _hardwareReady) {
          return WebDiscoveryMapboxV3(
            onClose: widget.onClose,
            showCitiesOnOpen: widget.showCitiesOnOpen,
          );
        }

        // Old/CPU-only browsers still get the stable 2D renderer instead of a
        // blank or fake globe. Modern Chrome/Safari remain on Mapbox end-to-end.
        return WebDiscoveryMapScreenV5(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        );
      },
    );
  }
}
