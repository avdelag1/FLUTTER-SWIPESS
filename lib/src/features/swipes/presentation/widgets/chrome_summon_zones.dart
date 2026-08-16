import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Invisible edge taps that bring the dashboard/deck chrome back.
///
/// Keep these zones at the physical edges only. A previous full-height
/// vertical-drag detector sat above the content while chrome was hidden and
/// could win the gesture arena against the page scroll, making scrolling feel
/// sticky or intermittently broken.
class ChromeSummonZones extends StatelessWidget {
  const ChromeSummonZones({
    super.key,
    required this.visible,
    required this.onSummon,
  });

  /// When chrome is already visible the strips must not intercept header taps.
  final bool visible;
  final VoidCallback onSummon;

  void _summon() {
    AppHaptics.light();
    onSummon();
  }

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
            onTap: _summon,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 120) _summon();
            },
          ),
        ),
        Positioned(
          left: MediaQuery.sizeOf(context).width * 0.08,
          right: MediaQuery.sizeOf(context).width * 0.08,
          bottom: bottom + 42,
          height: 36,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _summon,
          ),
        ),
      ],
    );
  }
}
