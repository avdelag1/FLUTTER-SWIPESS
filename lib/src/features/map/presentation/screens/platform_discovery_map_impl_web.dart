import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_globe_screen_v2.dart';

/// Web discovery keeps the real Mapbox globe, while Flutter projects the live
/// Swipess listings/users on top of it. This avoids Mapbox web-alpha annotation
/// managers without changing discovery data, coordinates, filters or routes.
Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return RealMapboxGlobeScreenV2(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
