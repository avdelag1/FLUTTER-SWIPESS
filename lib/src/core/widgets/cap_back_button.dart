import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// Shared compact back control used across phone pages.
///
/// Uses GoRouter history when available. Routes opened with `go()` do not have
/// a Navigator page to pop, so we fall back to the correct section dashboard
/// instead of leaving a dead back button on screen.
class CapBackButton extends ConsumerWidget {
  const CapBackButton({
    super.key,
    this.onTap,
    this.fallbackPath,
    this.color = Colors.white,
  });

  final VoidCallback? onTap;
  final String? fallbackPath;
  final Color color;

  String _currentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '';
    }
  }

  String _resolvedFallback(BuildContext context) {
    if (fallbackPath != null && fallbackPath!.isNotEmpty) return fallbackPath!;
    final path = _currentPath(context);
    if (path.startsWith('/admin/')) return AppPaths.adminDashboard;
    if (path.startsWith('/lawyer/')) return AppPaths.lawyerDashboard;
    if (path.startsWith('/business/')) return AppPaths.businessDashboard;
    if (path.startsWith('/owner/')) return AppPaths.ownerDashboard;
    return AppPaths.clientDashboard;
  }

  void _handleTap(BuildContext context) {
    AppHaptics.light();
    if (onTap != null) {
      onTap!();
      return;
    }

    if (context.canPop()) {
      context.pop();
      return;
    }

    final fallback = _resolvedFallback(context);
    final current = _currentPath(context);
    if (current != fallback) context.go(fallback);
  }

  bool _followsProfileChrome(BuildContext context) {
    final path = _currentPath(context);
    return path == AppPaths.clientProfile || path == AppPaths.ownerProfile;
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
                          : Colors.white.withAlpha(22),
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
                      size: 18,
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
