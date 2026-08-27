import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// A short, real Mapbox globe opening used before the discovery map.
///
/// The discovery map is always prewarmed underneath this widget. The globe is
/// intentionally transparent until Mapbox confirms that the style has loaded;
/// if WebGL/style initialization stalls or fails, a short watchdog removes the
/// intro without ever painting a grey/blank layer over the working map.
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

  static const double _worldZoom = 0.7;

  @override
  void initState() {
    super.initState();
    // This is intentionally much shorter than the outer bootstrap watchdog.
    // If the Mapbox web renderer cannot become ready, reveal the already-live
    // discovery map immediately instead of leaving an opaque platform surface.
    _loadWatchdog = Timer(const Duration(milliseconds: 2200), () {
      if (!_loaded) _finish();
    });
  }

  Point _point(double lat, double lng) =>
      Point(coordinates: Position(lng, lat));

  double _zoomForRadius(int km) {
    if (km <= 5) return 13.2;
    if (km <= 10) return 12.3;
    if (km <= 25) return 11.2;
    if (km <= 50) return 10.2;
    if (km <= 100) return 9.2;
    if (km <= 250) return 8.0;
    if (km <= 1000) return 5.8;
    if (km <= 5000) return 3.2;
    return 2.0;
  }

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    try {
      // Atlantic-centered world framing keeps the spherical Earth immediately
      // legible while leaving the Americas and Europe visible at launch.
      await map.setCamera(
        CameraOptions(
          center: _point(18, -28),
          zoom: _worldZoom,
          pitch: 0,
          bearing: 0,
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
    _startTimer = Timer(const Duration(milliseconds: 420), () async {
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
            pitch: 0,
            bearing: 0,
          ),
          MapAnimationOptions(duration: 2550, startDelay: 0),
        );
      } catch (_) {
        _finish();
        return;
      }

      if (!mounted || _completed) return;
      await Future<void>.delayed(const Duration(milliseconds: 140));
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
    return IgnorePointer(
      child: AnimatedOpacity(
        // Never reveal the Mapbox web surface until its style is really ready.
        // This is the critical guard against the grey full-screen layer seen on
        // browsers where WebGL initialization fails after widget construction.
        opacity: _loaded ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: MapWidget(
          key: const ValueKey('swipess-mapbox-world-intro'),
          styleUri: MapboxStyles.STREETS,
          onMapCreated: _setupMap,
          onMapLoadedListener: (_) => _onMapLoaded(),
        ),
      ),
    );
  }
}
