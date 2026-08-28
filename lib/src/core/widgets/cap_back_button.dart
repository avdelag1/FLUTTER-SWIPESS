import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// Shared compact back control used across phone pages.
///
/// The visual is intentionally just a floating icon. The invisible 44pt hit
/// target remains for accessibility and reliable phone taps; backgrounds,
/// circular frames and glass outlines are not painted.
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

    final nearest = Navigator.of(context);
    if (nearest.canPop()) {
      nearest.pop();
      return;
    }

    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop();
      return;
    }

    // Ignore GoRouter's canPop() because on iOS PWA (standalone) mode,
    // window.history.back() will silently fail if the browser stack is isolated.
    // Instead, always use a declarative fallback if the local Navigator stack is empty.
    context.go(_resolvedFallback(context));
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
    final iconColor = isLight ? const Color(0xFF111318) : color;
    final shadowColor = isLight
        ? Colors.white.withAlpha(210)
        : Colors.black.withAlpha(170);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            key: const ValueKey('cap-back-button'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleTap(context),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: iconColor,
                  size: 20,
                  shadows: [
                    Shadow(color: shadowColor, blurRadius: 5),
                    Shadow(color: shadowColor, blurRadius: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
