import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen.dart';

Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return WebDiscoveryMapScreen(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
