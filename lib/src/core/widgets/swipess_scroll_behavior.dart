import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared high-quality scrolling for touch, mouse, trackpad and stylus.
///
/// RangeMaintainingScrollPhysics prevents small media/layout changes from
/// kicking the viewport while the user is moving quickly back through a feed.
/// We keep native iOS elasticity, while Android/web stay crisp and clamped.
class SwipessScrollBehavior extends MaterialScrollBehavior {
  const SwipessScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kIsWeb) {
      return const RangeMaintainingScrollPhysics(
        parent: ClampingScrollPhysics(),
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS => const RangeMaintainingScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      _ => const RangeMaintainingScrollPhysics(parent: ClampingScrollPhysics()),
    };
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
