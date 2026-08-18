import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v3.dart';

Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return WebDiscoveryMapScreenV3(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
