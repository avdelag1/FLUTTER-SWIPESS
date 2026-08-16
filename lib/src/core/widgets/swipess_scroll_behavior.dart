import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Consistent, glow-free scrolling for touch, mouse, trackpad and stylus.
///
/// Keep iOS/macOS elastic scrolling native while avoiding the rubber-band feel
/// on web/Android/desktop platforms where it makes the app feel like an iOS
/// surface embedded inside another platform.
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
    if (kIsWeb) return const ClampingScrollPhysics();

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      _ => const ClampingScrollPhysics(),
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
