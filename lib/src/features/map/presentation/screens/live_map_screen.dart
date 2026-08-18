import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/fresh_mapbox_screen.dart';
import 'package:go_router/go_router.dart';

/// Compatibility entry point for the discovery map.
///
/// Swipess previously maintained two separate map engines. All entry points now
/// resolve to the same native Mapbox experience and refresh discovery data when
/// opened so a stale empty provider cannot make the map look dead.
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
    return FreshMapboxScreen(
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
