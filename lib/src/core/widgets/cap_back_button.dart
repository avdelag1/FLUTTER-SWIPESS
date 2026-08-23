import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// Shared compact back control used across phone pages.
class CapBackButton extends ConsumerWidget {
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

  bool _followsProfileChrome(BuildContext context) {
    try {
      final path = GoRouterState.of(context).uri.path;
      return path == AppPaths.clientProfile || path == AppPaths.ownerProfile;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final followsChrome = _followsProfileChrome(context);
    final chromeVisible = ref.watch(chromeVisibilityProvider);
    final visible = !followsChrome || chromeVisible;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Semantics(
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
                      border: isLight
                          ? Border.all(
                              color: Colors.black.withAlpha(18),
                              width: .7,
                            )
                          : null,
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
        ),
      ),
    );
  }
}
