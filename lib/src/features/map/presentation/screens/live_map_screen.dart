import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/platform_discovery_map_screen.dart';
import 'package:go_router/go_router.dart';

/// Compatibility entry point for the discovery map.
///
/// Every map entry resolves through the same platform-aware renderer: Flutter
/// rendering on web for reliable input/markers and Mapbox Maps SDK on native.
class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({
    super.key,
    this.asOverlay = false,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  /// Retained for backwards compatibility with existing callers.
  final bool asOverlay;
  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  Widget build(BuildContext context) {
    return PlatformDiscoveryMapScreen(
      showCitiesOnOpen: showCitiesOnOpen,
      onClose:
          onClose ??
          () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.go(AppPaths.clientDashboard);
            }
          },
    );
  }
}
