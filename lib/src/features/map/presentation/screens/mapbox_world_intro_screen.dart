import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// A short, real Mapbox globe opening used before the discovery map.
///
/// Mapbox Standard uses globe projection at low zoom, so this starts from a
/// true round Earth view and then performs a single cinematic flight into the
/// active Swipess city/location. It intentionally renders no markers or app UI
/// so the opening remains fast and cannot interfere with the discovery map.
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
  bool _started = false;
  bool _completed = false;

  static const double _worldZoom = 0.7;

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
    // Atlantic-centered world framing makes the spherical Earth immediately
    // legible while keeping the Americas and Europe visible during launch.
    await map.setCamera(
      CameraOptions(
        center: _point(18, -28),
        zoom: _worldZoom,
        pitch: 0,
        bearing: 0,
      ),
    );
  }

  void _beginFlight() {
    if (_started || !mounted) return;
    _started = true;
    _startTimer?.cancel();
    _startTimer = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      final map = _map;
      if (map == null) return;

      final loc = ref.read(discoveryLocationProvider);
      try {
        await map.flyTo(
          CameraOptions(
            center: _point(loc.latitude, loc.longitude),
            zoom: _zoomForRadius(loc.radiusKm),
            pitch: 0,
            bearing: 0,
          ),
          MapAnimationOptions(duration: 2800, startDelay: 0),
        );
      } catch (_) {
        // The platform bootstrap has its own watchdog and will reveal the
        // normal discovery map if the intro renderer cannot complete.
      }

      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      _finish();
    });
  }

  void _finish() {
    if (_completed || !mounted) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F8FA),
      child: IgnorePointer(
        child: MapWidget(
          key: const ValueKey('swipess-mapbox-world-intro'),
          // Mapbox Standard is deliberately used here: at low zoom it renders
          // the globe projection rather than the flat Mercator world.
          styleUri: MapboxStyles.STANDARD,
          onMapCreated: _setupMap,
          onMapLoadedListener: (_) => _beginFlight(),
        ),
      ),
    );
  }
}
