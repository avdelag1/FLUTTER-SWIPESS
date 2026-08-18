import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/stable_mapbox_screen.dart';
import 'package:go_router/go_router.dart';

/// Compatibility entry point for the discovery map.
///
/// Every map entry now uses the same failure-proof Mapbox implementation so
/// the dashboard overlay and the dedicated /map route cannot drift apart.
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
    return StableMapboxScreen(
      showCitiesOnOpen: showCitiesOnOpen,
      onClose: onClose ??
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
