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
List<MapClusterGroup> clusterMapPins(List<MapPin> pins, double zoom) {
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
