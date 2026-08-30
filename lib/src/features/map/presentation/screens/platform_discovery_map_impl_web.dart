import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_mapbox_v3.dart';

@JS('eval')
external JSAny? _eval(JSString code);

/// Prefer the persistent Mapbox surface whenever the browser can create any
/// WebGL2 context. Do not reject integrated/software renderers here: Flutter's
/// own renderer may report CPU-only mode on older Macs while a DOM-hosted
/// Mapbox canvas can still create a usable WebGL2 context. Mapbox should get a
/// chance to render instead of being pre-emptively forced onto the 2D fallback.
bool _browserSupportsPersistentMapbox() {
  try {
    final result = _eval(
      r'''
      (function () {
        var gl = null;
        try {
          var canvas = document.createElement('canvas');
          gl = canvas.getContext('webgl2', {
            antialias: true,
            alpha: true,
            depth: true,
            stencil: true
          });
          return !!gl;
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
  late bool _showIntro;
  bool _audioSuppressed = false;
  bool? _lastRouteActive;

  @override
  void initState() {
    super.initState();
    _showIntro = true;
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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Material(
            color: Color(0xFF06182B),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4D78)),
              ),
            ),
          );
        }

        if (snapshot.data == true && _hardwareReady) {
          return WebDiscoveryMapboxV3(
            onClose: widget.onClose,
            showCitiesOnOpen: widget.showCitiesOnOpen,
            playIntro: _showIntro,
            onIntroComplete: () => _showIntro = false,
          );
        }

        // Only use the 2D safety renderer when WebGL2 truly cannot be created
        // or Mapbox could not be configured. Do not silently show it while the
        // Mapbox runtime check is still in progress.
        return WebDiscoveryMapScreenV5(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        );
      },
    );
  }
}
