import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_scroll_behavior.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('supports touch, mouse, trackpad and stylus without glow', (
    tester,
  ) async {
    const behavior = SwipessScrollBehavior();
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: behavior,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return ListView(children: const [SizedBox(height: 1200)]);
          },
        ),
      ),
    );

    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    expect(behavior.dragDevices, contains(PointerDeviceKind.stylus));

    const child = SizedBox(key: ValueKey('scroll-child'));
    final wrapped = behavior.buildOverscrollIndicator(
      context,
      child,
      const ScrollableDetails(direction: AxisDirection.down),
    );
    expect(identical(wrapped, child), isTrue);
  });

  testWidgets('uses native bounce on iOS and clamping on Android', (
    tester,
  ) async {
    const behavior = SwipessScrollBehavior();
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(behavior.getScrollPhysics(context), isA<BouncingScrollPhysics>());

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(behavior.getScrollPhysics(context), isA<ClampingScrollPhysics>());
  });
}
