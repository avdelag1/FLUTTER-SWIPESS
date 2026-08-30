import 'dart:math' as math;

/// Groups nearby map pins so the UI can show one avatar + "+N more".
class MapPinCluster<T> {
  const MapPinCluster({
    required this.lat,
    required this.lng,
    required this.items,
  });

  final double lat;
  final double lng;
  final List<T> items;

  T get head => items.first;
  int get extraCount => math.max(0, items.length - 1);
  String get clusterKey => items.map((e) => clusterId(e)).join('|');

  static String clusterId(dynamic item) {
    if (item is Map<String, dynamic>) return item['id']?.toString() ?? '';
    try {
      return (item as dynamic).key as String;
    } catch (_) {}
    try {
      return (item as dynamic).id as String;
    } catch (_) {}
    return item.toString();
  }
}

abstract final class MapPinClustering {
  /// Cluster pins within [cellMeters] of each other (Haversine).
  static List<MapPinCluster<T>> cluster<T>({
    required List<T> items,
    required double Function(T item) latOf,
    required double Function(T item) lngOf,
    double cellMeters = 85,
  }) {
    if (items.isEmpty) return const [];
    if (items.length == 1) {
      return [
        MapPinCluster(
          lat: latOf(items.first),
          lng: lngOf(items.first),
          items: items,
        ),
      ];
    }

    final clusters = <MapPinCluster<T>>[];
    final used = <int>{};

    for (var i = 0; i < items.length; i++) {
      if (used.contains(i)) continue;
      final seed = items[i];
      final group = <T>[seed];
      used.add(i);
      for (var j = i + 1; j < items.length; j++) {
        if (used.contains(j)) continue;
        final other = items[j];
        final d = _haversineMeters(
          latOf(seed),
          lngOf(seed),
          latOf(other),
          lngOf(other),
        );
        if (d <= cellMeters) {
          group.add(other);
          used.add(j);
        }
      }
      final lat =
          group.map(latOf).reduce((a, b) => a + b) / group.length;
      final lng =
          group.map(lngOf).reduce((a, b) => a + b) / group.length;
      clusters.add(MapPinCluster(lat: lat, lng: lng, items: group));
    }
    return clusters;
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
