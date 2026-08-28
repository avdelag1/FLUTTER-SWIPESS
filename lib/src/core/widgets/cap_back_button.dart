import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// Shared back-navigation helper for phone pages and overlays.
///
/// GoRouter pages in Swipess are frequently entered with `context.go()`. In
/// web/PWA builds Flutter's Navigator can still report `canPop == true` for an
/// internal route that is not the user's previous screen. Popping that route
/// can immediately redirect back to the same location, which makes the back
/// button look dead.
///
/// For an app-routed page we therefore navigate declaratively to a known safe
/// parent first. Navigator.pop is reserved for local/pushed routes where there
/// is no GoRouter location available.
abstract final class NavBack {
  static String resolvedFallback(BuildContext context, {String? fallbackPath}) {
    if (fallbackPath != null && fallbackPath.isNotEmpty) return fallbackPath;
    final path = _currentPath(context);

    // Keep detail pages inside the section the user came from whenever there
    // is a deterministic parent route.
    if (path == AppPaths.exploreEventsLikes ||
        path.startsWith('${AppPaths.exploreEvents}/')) {
      return AppPaths.exploreEvents;
    }
    if (path.startsWith('${AppPaths.messages}/')) return AppPaths.messages;
    if (path == AppPaths.clientVapIdEdit) return AppPaths.clientVapId;

    // Workspace-safe fallbacks.
    if (path.startsWith('/admin/')) return AppPaths.adminDashboard;
    if (path.startsWith('/lawyer/')) return AppPaths.lawyerDashboard;
    if (path.startsWith('/business/')) return AppPaths.businessDashboard;
    if (path.startsWith('/owner/')) return AppPaths.ownerDashboard;

    // Profile/settings pages should return to profile rather than jumping
    // through an unrelated navigator stack.
    if (path == AppPaths.clientSettings ||
        path == AppPaths.clientSavedSearches ||
        path == AppPaths.clientSecurity ||
        path == AppPaths.clientAdvertise ||
        path == AppPaths.clientPerks) {
      return AppPaths.clientProfile;
    }

    return AppPaths.clientDashboard;
  }

  static String _currentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '';
    }
  }

  static void popOrGo(
    BuildContext context, {
    String? fallbackPath,
    VoidCallback? onTap,
  }) {
    AppHaptics.light();
    if (onTap != null) {
      onTap();
      return;
    }

    final currentPath = _currentPath(context);
    final fallback = resolvedFallback(context, fallbackPath: fallbackPath);
    final router = GoRouter.maybeOf(context);

    // This is the critical PWA/native parity rule: if this widget belongs to a
    // GoRouter page, do not trust Navigator.canPop(). Move to the deterministic
    // parent route immediately. It is synchronous and cannot silently pop into
    // a redirect loop.
    if (router != null && currentPath.isNotEmpty && currentPath != fallback) {
      router.go(fallback);
      return;
    }

    // Only local routes/dialog-style pages should reach Navigator.pop.
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

    if (router != null && currentPath != fallback) {
      router.go(fallback);
    }
  }
}

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

  void _handleTap(BuildContext context) {
    NavBack.popOrGo(
      context,
      fallbackPath: fallbackPath,
      onTap: onTap,
    );
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
      ignoring: false,
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
