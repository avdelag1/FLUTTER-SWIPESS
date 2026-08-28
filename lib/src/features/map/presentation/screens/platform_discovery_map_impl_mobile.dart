import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen_v2.dart';

// The globe is a cinematic arrival, not a loading tax. Show it once per app
// process; every later Map open goes straight to the live discovery map.
bool _nativeMapIntroShownThisSession = false;

/// Native iOS/Android map entry point.
///
/// Native must stay on the Mapbox SDK. Before creating any Mapbox surface we
/// guarantee that a public access token is configured. Store/TestFlight builds
/// do not always receive Flutter dart-defines, so relying only on main.dart can
/// create a native map with no token and leave the user on a permanent loader.
Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return _NativeMapBootstrap(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}

class _NativeMapBootstrap extends ConsumerStatefulWidget {
  const _NativeMapBootstrap({
    required this.onClose,
    required this.showCitiesOnOpen,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<_NativeMapBootstrap> createState() =>
      _NativeMapBootstrapState();
}

class _NativeMapBootstrapState extends ConsumerState<_NativeMapBootstrap> {
  late Future<bool> _mapboxReady;
  late final DeckAudioNotifier _audioNotifier;

  // A newly opened map route gets the cinematic globe only once per app
  // session. Pushing a listing on top keeps this State alive, so Back returns
  // to the exact live map without replaying the intro or navigation stack.
  late bool _showIntro;
  bool _audioSuppressed = false;
  bool? _lastTickerActive;

  @override
  void initState() {
    super.initState();
    _audioNotifier = ref.read(deckSoundOnProvider.notifier);
    _showIntro = !_nativeMapIntroShownThisSession;
    _mapboxReady = _configureMapbox();
  }

  Future<bool> _configureMapbox() => MapboxRuntimeConfig.ensureConfigured()
      .timeout(const Duration(seconds: 5), onTimeout: () => false);

  void _retryMapbox() {
    setState(() {
      _showIntro = !_nativeMapIntroShownThisSession;
      _mapboxReady = _configureMapbox();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (_lastTickerActive == active) return;
    _lastTickerActive = active;
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

  Widget _loading() {
    return const Material(
      color: Color(0xFF06182B),
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF4D78),
          ),
        ),
      ),
    );
  }

  Widget _unavailable() {
    return Material(
      color: const Color(0xFFF1F4F7),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 34,
                  color: Color(0xFF111318),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Map could not connect',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF111318),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5F6670),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retryMapbox,
                  child: const Text('Retry'),
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always paint an opaque map canvas. The intro MapWidget used to fade from
    // transparent, which exposed the dashboard underneath and looked exactly
    // like the map had crashed/closed before reappearing a few seconds later.
    return ColoredBox(
      color: const Color(0xFFF1F4F7),
      child: FutureBuilder<bool>(
        future: _mapboxReady,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _loading();
          }

          if (snapshot.data != true) {
            return _unavailable();
          }

          if (_showIntro) {
            return MapboxWorldIntroScreen(
              onComplete: () {
                if (!mounted) return;
                _nativeMapIntroShownThisSession = true;
                setState(() => _showIntro = false);
              },
            );
          }

          return RealMapboxScreenV2(
            onClose: widget.onClose,
            showCitiesOnOpen: widget.showCitiesOnOpen,
          );
        },
      ),
    );
  }
}
