import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen.dart';

/// Web discovery now uses the real Mapbox renderer again so the user sees the
/// actual rounded globe rather than a perspective transform applied to flat
/// raster tiles. Keep this switch intentionally small: the existing discovery
/// providers, listings/users, coordinates, filters, radius and navigation are
/// reused unchanged by [RealMapboxScreen].
Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return RealMapboxScreen(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
