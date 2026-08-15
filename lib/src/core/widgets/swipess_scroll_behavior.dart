import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Consistent, glow-free bouncing scrolling for touch, mouse, trackpad and stylus.
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
    // Always use BouncingScrollPhysics to make scrolling feel kinetic, fast, and sensible, especially on Web.
    return const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
