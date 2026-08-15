import 'dart:math' as math;
import 'package:flutter_swipes/src/features/map/data/map_camera.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:latlong2/latlong.dart';

/// One map marker that may wrap several overlapping pins.
class MapClusterGroup {
  const MapClusterGroup({required this.point, required this.pins});

  final LatLng point;
  final List<MapPin> pins;

  int get count => pins.length;
}

/// Cluster passport pins. Nearby-but-distinct listings stay separate so a
/// 50 km zoom never collapses a city into a single bubble.



List<MapPin> _scatterOverlaps(List<MapPin> raw) {
  final exact = <String, List<MapPin>>{};
  for (final p in raw) {
    final key = '${p.lat.toStringAsFixed(4)}_${p.lng.toStringAsFixed(4)}';
    exact.putIfAbsent(key, () => []).add(p);
  }
  
  final scattered = <MapPin>[];
  for (final group in exact.values) {
    if (group.length == 1) {
      scattered.add(group.first);
    } else {
      final baseRadius = 0.002; // ~200 meters
      for (var i = 0; i < group.length; i++) {
        final rand = math.Random(group[i].id.hashCode);
        final r = baseRadius + (rand.nextDouble() * 0.008); // up to ~1km
        final angle = rand.nextDouble() * 2 * math.pi;
        
        final dLat = r * math.cos(angle);
        final dLng = r * math.sin(angle);
        scattered.add(MapPin.scattered(group[i], group[i].lat + dLat, group[i].lng + dLng));
      }
    }
  }
  return scattered;
}

List<MapClusterGroup> clusterMapPins(List<MapPin> originalPins, double zoom) {
  final pins = _scatterOverlaps(originalPins);

  if (pins.isEmpty) return const [];
  if (pins.length <= MapCameraMath.alwaysShowBelow) {
    return [
      for (final p in pins)
        MapClusterGroup(point: LatLng(p.lat, p.lng), pins: [p]),
    ];
  }
  final cell = MapCameraMath.clusterCellDegrees(zoom);
  final buckets = <String, List<MapPin>>{};
  for (final p in pins) {
    final key = '${(p.lat / cell).floor()}_${(p.lng / cell).floor()}';
    buckets.putIfAbsent(key, () => []).add(p);
  }
  return [
    for (final group in buckets.values)
      MapClusterGroup(
        point: LatLng(
          group.map((e) => e.lat).reduce((a, b) => a + b) / group.length,
          group.map((e) => e.lng).reduce((a, b) => a + b) / group.length,
        ),
        pins: group,
      ),
  ];
}
