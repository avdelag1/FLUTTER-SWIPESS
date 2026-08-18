import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen.dart';

Widget buildPlatformDiscoveryMap({
  required VoidCallback? onClose,
  required bool showCitiesOnOpen,
}) {
  return RealMapboxScreen(
    onClose: onClose,
    showCitiesOnOpen: showCitiesOnOpen,
  );
}
