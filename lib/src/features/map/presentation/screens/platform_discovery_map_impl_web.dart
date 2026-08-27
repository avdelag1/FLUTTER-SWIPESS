import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/map/data/map_basemap.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_runtime_config.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/mapbox_world_intro_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';
import 'package:latlong2/latlong.dart';

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
    // Never use ref.read from dispose. Riverpod intentionally rejects reads
    // once a ConsumerState has started unmounting. The notifier is captured
    // while mounted so temporary map audio suppression can always be released.
    _restoreAudio();
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

        // Returning to Map later in the same running app goes straight back to
        // the existing discovery experience. No repeated intro interruption.
        if (!_playIntro) return discoveryMap;

        _armIntroWatchdog();

        // A true Mapbox sphere requires WebGL2. If the browser is CPU-only,
        // preserve the same round-world experience with the CPU-safe basemap
        // globe instead of ever showing a broken/grey Mapbox surface.
        if (snapshot.data != true || !_globeReady) {
          return Stack(
            fit: StackFit.expand,
            children: [
              discoveryMap,
              if (!_introComplete)
                Positioned.fill(
                  child: _CpuSafeWorldIntro(onComplete: _finishIntro),
                ),
            ],
          );
        }

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

/// CPU-safe globe illusion used only when the browser cannot create the WebGL2
/// context required by Mapbox GL. The world is still the real Mapbox/Carto
/// raster basemap, clipped and shaded as a sphere. The underlying discovery map
/// performs the geographic world-to-city flight at the same time.
class _CpuSafeWorldIntro extends StatefulWidget {
  const _CpuSafeWorldIntro({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_CpuSafeWorldIntro> createState() => _CpuSafeWorldIntroState();
}

class _CpuSafeWorldIntroState extends State<_CpuSafeWorldIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final launch = ((t - .30) / .58).clamp(0.0, 1.0);
          final easedLaunch = Curves.easeInOutCubic.transform(launch);
          final fade = t <= .64
              ? 1.0
              : (1.0 - ((t - .64) / .30).clamp(0.0, 1.0));
          final scale = 1.0 + easedLaunch * 1.9;
          final rotation = -0.045 + easedLaunch * 0.08;

          return Opacity(
            opacity: fade,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortest = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final diameter = (shortest * .68).clamp(260.0, 620.0);

                return Center(
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: diameter,
                        height: diameter,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 42,
                              spreadRadius: 6,
                              offset: Offset(0, 18),
                            ),
                            BoxShadow(
                              color: Color(0x22FFFFFF),
                              blurRadius: 22,
                              spreadRadius: 2,
                              offset: Offset(-12, -12),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FlutterMap(
                                options: const MapOptions(
                                  initialCenter: LatLng(18, -28),
                                  initialZoom: .58,
                                  minZoom: .4,
                                  maxZoom: 2.0,
                                  interactionOptions: InteractionOptions(
                                    flags: InteractiveFlag.none,
                                  ),
                                  backgroundColor: Color(0xFFDCEAF3),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: MapBasemap.urlTemplate(true),
                                    subdomains: MapBasemap.subdomains,
                                    additionalOptions:
                                        MapBasemap.additionalOptions,
                                    userAgentPackageName:
                                        MapBasemap.userAgentPackageName,
                                    tileDimension: 256,
                                    maxNativeZoom: 19,
                                    keepBuffer: 3,
                                  ),
                                ],
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: Alignment(-.30, -.34),
                                    radius: .95,
                                    colors: [
                                      Color(0x00FFFFFF),
                                      Color(0x08000000),
                                      Color(0x52000000),
                                    ],
                                    stops: [.46, .74, 1],
                                  ),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(
                                      color: Color(0x66FFFFFF),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
