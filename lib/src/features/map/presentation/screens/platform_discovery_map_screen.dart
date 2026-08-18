import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/platform_discovery_map_impl_mobile.dart'
    if (dart.library.html) 'package:flutter_swipes/src/features/map/presentation/screens/platform_discovery_map_impl_web.dart';

/// One public map entry point with a renderer chosen at compile time.
///
/// Web compiles only the Flutter-rendered map. Native compiles only the
/// Mapbox SDK map. This prevents unsupported web Mapbox APIs from entering
/// the browser build or stealing pointer events from Flutter controls.
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
    return buildPlatformDiscoveryMap(
      onClose: onClose,
      showCitiesOnOpen: showCitiesOnOpen,
    );
  }
}
