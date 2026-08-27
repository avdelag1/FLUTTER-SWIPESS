import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen_v2.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';

bool _nativeGlobePlayedThisSession = false;

Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return _NativeDiscoveryMapBootstrap(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}

class _NativeDiscoveryMapBootstrap extends ConsumerStatefulWidget {
  const _NativeDiscoveryMapBootstrap({
    required this.onClose,
    required this.showCitiesOnOpen,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<_NativeDiscoveryMapBootstrap> createState() =>
      _NativeDiscoveryMapBootstrapState();
}

class _NativeDiscoveryMapBootstrapState
    extends ConsumerState<_NativeDiscoveryMapBootstrap> {
  late final Future<bool> _mapboxReady = MapboxRuntimeConfig.ensureConfigured();
  late final bool _playIntro;
  late final DeckAudioNotifier _audioNotifier;
  Timer? _introWatchdog;
  Timer? _mapLoadWatchdog;
  bool _introWatchdogArmed = false;
  bool _introComplete = false;
  bool _watchdogArmed = false;
  bool _nativeMapReportedReady = false;
  bool _useFallback = false;
  bool _audioSuppressed = false;
  bool? _lastRouteActive;

  @override
  void initState() {
    super.initState();
    _audioNotifier = ref.read(deckSoundOnProvider.notifier);
    _playIntro = !_nativeGlobePlayedThisSession;
    if (_playIntro) _nativeGlobePlayedThisSession = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
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
    if (_introWatchdogArmed || _introComplete || _useFallback) return;
    _introWatchdogArmed = true;
    _introWatchdog = Timer(const Duration(seconds: 10), _finishIntro);
  }

  void _finishIntro() {
    if (!mounted || _introComplete) return;
    _introWatchdog?.cancel();
    setState(() => _introComplete = true);
  }

  void _armWatchdog() {
    if (_watchdogArmed || _nativeMapReportedReady || _useFallback) return;
    _watchdogArmed = true;
    _mapLoadWatchdog = Timer(const Duration(seconds: 8), () {
      if (!mounted || _nativeMapReportedReady) return;
      setState(() => _useFallback = true);
    });
  }

  void _markNativeMapReady() {
    _nativeMapReportedReady = true;
    _mapLoadWatchdog?.cancel();
  }

  @override
  void dispose() {
    _introWatchdog?.cancel();
    _mapLoadWatchdog?.cancel();
    // Never call ref.read from dispose. Keep the notifier captured while the
    // ConsumerState is mounted so map audio can always be restored safely.
    _restoreAudio();
    super.dispose();
  }

  Widget _transition(Widget child, String key) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
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

        if (snapshot.data == true && !_useFallback) {
          // iOS + Android use the original Mapbox round-world intro on the first
          // map opening of the running app session, then continue into the
          // native Mapbox discovery map. Re-entering Map does not replay it.
          if (_playIntro && !_introComplete) {
            _armIntroWatchdog();
            return _transition(
              MapboxWorldIntroScreen(onComplete: _finishIntro),
              'mapbox-world-intro',
            );
          }

          _armWatchdog();
          return _transition(
            RealMapboxScreenV2(
              onClose: widget.onClose,
              showCitiesOnOpen: widget.showCitiesOnOpen,
              onMapReady: _markNativeMapReady,
            ),
            'native-discovery-map',
          );
        }

        // Safety only: if native Mapbox cannot initialize, use the working
        // Flutter-rendered discovery map rather than a blank surface.
        return _transition(
          WebDiscoveryMapScreenV5(
            onClose: widget.onClose,
            showCitiesOnOpen: widget.showCitiesOnOpen,
          ),
          'native-map-safety-view',
        );
      },
    );
  }
}
