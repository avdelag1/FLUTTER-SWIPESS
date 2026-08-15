import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Consistent, glow-free scrolling for touch, mouse, trackpad and stylus.
///
/// Apple platforms keep their familiar soft edge bounce. Android, Windows and
/// Linux use clamping physics so long feeds stop precisely without the default
/// Material overscroll glow obscuring the black Swipess canvas.
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
    return switch (getPlatform(context)) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        const BouncingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        ),
      _ => const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        ),
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
}
