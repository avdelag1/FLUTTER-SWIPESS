import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v4.dart';

/// Browser discovery uses the Flutter-rendered map surface. This avoids the
/// Mapbox WebGL platform-view alpha path that can render as a black rectangle
/// while the surrounding Flutter controls remain visible.
Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return WebDiscoveryMapScreenV4(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
