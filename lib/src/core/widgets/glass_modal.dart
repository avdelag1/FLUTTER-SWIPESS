import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/motion/ios_motion.dart';

/// Shows a bottom sheet with a frosted glass background overlay.
Future<T?> showGlassModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double heightFactor = 0.85,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: IosMotion.modalBarrier,
    enableDrag: true,
    useSafeArea: true,
    sheetAnimationStyle: IosMotion.sheetAnimation,
    builder: (context) {
      final isLight = Theme.of(context).brightness == Brightness.light;
      final sheet = Container(
        height: MediaQuery.of(context).size.height * heightFactor,
        decoration: BoxDecoration(
          color: isLight
              ? const Color.fromRGBO(248, 248, 252, kIsWeb ? 0.96 : 0.88)
              : const Color.fromRGBO(16, 16, 20, kIsWeb ? 0.96 : 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.45),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: builder(context)),
          ],
        ),
      );

      if (kIsWeb) return sheet;

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: sheet,
        ),
      );
    },
  );
}
