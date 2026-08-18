import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/stable_mapbox_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen.dart';

/// One public map entry point with a renderer chosen for platform reliability.
/// Web stays entirely in Flutter's render tree; native keeps Mapbox Maps SDK.
class PlatformDiscoveryMapScreen extends StatelessWidget {
  const PlatformDiscoveryMapScreen({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebDiscoveryMapScreen(
        onClose: onClose,
        showCitiesOnOpen: showCitiesOnOpen,
      );
    }

    return StableMapboxScreen(
      onClose: onClose,
      showCitiesOnOpen: showCitiesOnOpen,
    );
  }
}
