import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v4.dart';

/// Stable browser discovery renderer.
///
/// Keep the map surface, listings, people, radius and current-location marker
/// inside the same Flutter render tree. This prevents projected overlay pins
/// from lagging behind the Mapbox camera while the user pans or zooms.
/// Native iOS/Android still use the real Mapbox SDK renderer.
Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return WebDiscoveryMapScreenV4(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
