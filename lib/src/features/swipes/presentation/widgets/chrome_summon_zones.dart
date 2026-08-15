import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Cap `ChromeSummonZones` — invisible edge taps that bring HUD chrome back.
class ChromeSummonZones extends StatelessWidget {
  const ChromeSummonZones({
    super.key,
    required this.visible,
    required this.onSummon,
  });

  /// When chrome is already visible the strips must not intercept header taps.
  final bool visible;
  final VoidCallback onSummon;

  @override
  Widget build(BuildContext context) {
    if (visible) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top + 56,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 120) {
                AppHaptics.light();
                onSummon();
              }
            },
            onTap: () {
              AppHaptics.light();
              onSummon();
            },
          ),
        ),
        Positioned(
          top: top + 56,
          bottom: bottom + 78,
          left: MediaQuery.sizeOf(context).width * 0.24,
          right: MediaQuery.sizeOf(context).width * 0.24,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 120) {
                AppHaptics.light();
                onSummon();
              }
            },
          ),
        ),
        Positioned(
          left: MediaQuery.sizeOf(context).width * 0.08,
          right: MediaQuery.sizeOf(context).width * 0.08,
          bottom: bottom + 50,
          height: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              AppHaptics.light();
              onSummon();
            },
          ),
        ),
      ],
    );
  }
}
