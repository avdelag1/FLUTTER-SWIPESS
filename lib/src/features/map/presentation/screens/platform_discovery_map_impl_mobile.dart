import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen_v2.dart';

/// Native iOS/Android map entry point.
///
/// Native must stay on the Mapbox SDK. The web implementation uses browser
/// fallbacks, but compiling that implementation into iOS/Android turns the live
/// discovery experience into a 2D FlutterMap and also drags web-only APIs into
/// the native build.
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
  /// Intro is cinematic welcome, not navigation chrome. It plays only once for
  /// the lifetime of the running Flutter process. Re-opening Map, returning
  /// from a listing, or switching tabs goes directly to the live Mapbox map.
  static bool _introPlayedThisSession = false;

  late bool _showIntro;
  late final DeckAudioNotifier _audioNotifier;
  bool _audioSuppressed = false;
  bool? _lastTickerActive;

  @override
  void initState() {
    super.initState();
    _audioNotifier = ref.read(deckSoundOnProvider.notifier);
    _showIntro = !_introPlayedThisSession;
    if (_showIntro) _introPlayedThisSession = true;
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
    // The notifier is captured while mounted; never call ref.read from dispose.
    _restoreAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return MapboxWorldIntroScreen(
        onComplete: () {
          if (!mounted) return;
          setState(() => _showIntro = false);
        },
      );
    }

    return RealMapboxScreenV2(
      onClose: widget.onClose,
      showCitiesOnOpen: widget.showCitiesOnOpen,
    );
  }
}
