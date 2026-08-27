import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// A cinematic real-Mapbox globe opening used before the discovery map.
///
/// The discovery map is prewarmed underneath this widget. The globe remains
/// transparent until Mapbox confirms the style is loaded, so a failed WebGL
/// surface can never cover the working map with a grey/blank layer.
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

  // A little farther out than before so the whole spherical Earth is obvious.
  static const double _worldZoom = 0.52;

  @override
  void initState() {
    super.initState();
    // Only guards initialization. Once Mapbox is really loaded, the full
    // cinematic hold + flight is intentionally allowed to run.
    _loadWatchdog = Timer(const Duration(milliseconds: 2800), () {
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
      // Atlantic-centered framing keeps the Americas, Europe and Africa visible
      // while making the round Earth immediately legible.
      await map.setCamera(
        CameraOptions(
          center: _point(18, -28),
          zoom: _worldZoom,
          pitch: 0,
          bearing: -8,
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

    // Let the user actually enjoy the globe before moving toward the city.
    _startTimer = Timer(const Duration(milliseconds: 1900), () async {
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
          // Deliberately slower than the old 2.55s flight.
          MapAnimationOptions(duration: 4800, startDelay: 0),
        );
      } catch (_) {
        _finish();
        return;
      }

      if (!mounted || _completed) return;
      await Future<void>.delayed(const Duration(milliseconds: 260));
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
        opacity: _loaded ? 1 : 0,
        duration: const Duration(milliseconds: 300),
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
