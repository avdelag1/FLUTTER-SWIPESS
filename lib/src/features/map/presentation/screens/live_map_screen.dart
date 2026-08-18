import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen.dart';
import 'package:go_router/go_router.dart';

/// Compatibility entry point for the discovery map.
///
/// Swipess previously maintained two separate map engines: this route used a
/// Flutter-rendered map while the dashboard overlay used the native Mapbox
/// experience. Keeping both active caused visual drift, duplicate marker logic,
/// different interaction behavior, and extra performance work.
///
/// All entry points now resolve to the same Mapbox implementation so the map
/// feels identical regardless of where the user opens it from.
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
    return RealMapboxScreen(
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
