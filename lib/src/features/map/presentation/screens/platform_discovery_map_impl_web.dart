import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v5.dart';

/// Browser discovery keeps the stable Flutter-rendered Mapbox tile surface,
/// while using the same premium discovery language as the native map.
Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return WebDiscoveryMapScreenV5(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
