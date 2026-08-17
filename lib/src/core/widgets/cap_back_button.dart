import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// Shared compact back control used across phone pages.
class CapBackButton extends StatelessWidget {
  const CapBackButton({
    super.key,
    this.onTap,
    this.fallbackPath = AppPaths.clientDashboard,
    this.color = Colors.white,
  });

  final VoidCallback? onTap;
  final String fallbackPath;
  final Color color;

  Future<void> _handleTap(BuildContext context) async {
    AppHaptics.light();
    if (onTap != null) {
      onTap!();
      return;
    }
    final navigator = Navigator.of(context);
    final popped = await navigator.maybePop();
    if (!popped && context.mounted) context.go(fallbackPath);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          key: const ValueKey('cap-back-button'),
          onTap: () => _handleTap(context),
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          radius: 22,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLight
                      ? Colors.white.withAlpha(178)
                      : Colors.white.withAlpha(16),
                  border: Border.all(
                    color: Colors.white.withAlpha(isLight ? 105 : 48),
                    width: .7,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isLight ? const Color(0xFF111318) : color,
                  size: 17,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
