import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Cinematic native Mapbox opening.
///
/// Mapbox Standard renders a true globe at low zoom. This screen is shown only
/// once per app session by the native bootstrap, then flies from the round Earth
/// into the active discovery location. The animation is deliberately paced so
/// users can enjoy the globe-to-city zoom before the live map takes over.
class MapboxWorldIntroScreen extends ConsumerStatefulWidget {
  const MapboxWorldIntroScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  ConsumerState<MapboxWorldIntroScreen> createState() =>
      _MapboxWorldIntroScreenState();
}

class _MapboxWorldIntroScreenState
    extends ConsumerState<MapboxWorldIntroScreen> {
  MapboxMap? _map;
  Timer? _startTimer;
  Timer? _loadWatchdog;
  bool _started = false;
  bool _completed = false;
  bool _loaded = false;

  static const double _worldZoom = 0.62;
  static const _globeHold = Duration(milliseconds: 1100);
  static const _flightDuration = Duration(milliseconds: 3200);
  static const _arrivalHold = Duration(milliseconds: 420);

  @override
  void initState() {
    super.initState();
    // Never trap the user behind the cinematic if Mapbox cannot load.
    _loadWatchdog = Timer(const Duration(seconds: 8), () {
      if (!_loaded) _finish();
    });
  }

  Point _point(double lat, double lng) =>
      Point(coordinates: Position(lng, lat));

  double _zoomForRadius(int km) {
    if (km <= 5) return 13.4;
    if (km <= 10) return 12.5;
    if (km <= 25) return 11.4;
    if (km <= 50) return 10.4;
    if (km <= 100) return 9.4;
    if (km <= 250) return 8.2;
    if (km <= 1000) return 5.9;
    if (km <= 5000) return 3.2;
    return 2.0;
  }

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    try {
      await map.setCamera(
        CameraOptions(
          center: _point(18, -28),
          zoom: _worldZoom,
          pitch: 0,
          bearing: -10,
        ),
      );
    } catch (_) {
      _finish();
    }
  }

  void _onMapLoaded() {
    if (_completed || !mounted) return;
    _loadWatchdog?.cancel();
    setState(() => _loaded = true);
    _beginFlight();
  }

  void _beginFlight() {
    if (_started || !mounted) return;
    _started = true;
    _startTimer?.cancel();

    _startTimer = Timer(_globeHold, () async {
      if (!mounted || _completed) return;
      final map = _map;
      if (map == null) {
        _finish();
        return;
      }

      final loc = ref.read(discoveryLocationProvider);
      try {
        await map.flyTo(
          CameraOptions(
            center: _point(loc.latitude, loc.longitude),
            zoom: _zoomForRadius(loc.radiusKm),
            pitch: loc.radiusKm <= 50 ? 38 : 18,
            bearing: loc.radiusKm <= 50 ? 18 : 0,
          ),
          MapAnimationOptions(
            duration: _flightDuration.inMilliseconds,
            startDelay: 0,
          ),
        );
      } catch (_) {
        _finish();
        return;
      }

      if (!mounted || _completed) return;
      await Future<void>.delayed(_arrivalHold);
      _finish();
    });
  }

  void _finish() {
    if (_completed || !mounted) return;
    _completed = true;
    _startTimer?.cancel();
    _loadWatchdog?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _loadWatchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);

    return ColoredBox(
      color: const Color(0xFF06182B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: MapWidget(
              key: const ValueKey('swipess-mapbox-world-intro'),
              styleUri: MapboxStyles.STANDARD,
              onMapCreated: _setupMap,
              onMapLoadedListener: (_) => _onMapLoaded(),
            ),
          ),
          if (!_loaded)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF06182B),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF4D78),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: safe.top + 10,
            right: 14,
            child: TextButton(
              onPressed: () {
                AppHaptics.light();
                _finish();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0x66111827),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text(
                'Skip',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (_loaded)
            Positioned(
              left: 0,
              right: 0,
              bottom: safe.bottom + 28,
              child: Center(
                child: Text(
                  'Flying to your area…',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withAlpha(210),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: .3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
