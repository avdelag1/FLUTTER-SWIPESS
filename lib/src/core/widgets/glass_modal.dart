import 'dart:ui';
import 'package:flutter/material.dart';

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
    barrierColor: Colors.black.withAlpha(150),
    builder: (context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: MediaQuery.of(context).size.height * heightFactor,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light ? const Color.fromRGBO(240, 240, 245, 0.85) : const Color.fromRGBO(16, 16, 20, 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 1.5),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Grabber pill
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: builder(context),
              ),
            ],
          ),
        ),
      );
    },
  );
}
