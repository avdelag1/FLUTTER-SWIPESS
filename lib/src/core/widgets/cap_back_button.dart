import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_navigation_history.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// Shared back-navigation helper for phone pages and overlays.
///
/// Swipess mixes three navigation layers:
/// - GoRouter pages (`context.go` / `context.push`).
/// - Locally pushed Flutter routes (`Navigator.push`).
/// - Popup routes used by dialogs/sheets.
///
/// Back always prefers a real pop first because that preserves the exact page
/// instance, scroll position and filter/wizard state. When web/router history
/// points somewhere different from the page the user actually came from, the
/// app-level route history repairs the result instead of sending them through
/// another unrelated Back page and eventually Dashboard.
abstract final class NavBack {
  static String resolvedFallback(BuildContext context, {String? fallbackPath}) {
    if (fallbackPath != null && fallbackPath.isNotEmpty) return fallbackPath;
    final path = _currentPath(context);

    if (path == AppPaths.exploreEventsLikes ||
        path.startsWith('${AppPaths.exploreEvents}/')) {
      return AppPaths.exploreEvents;
    }
    if (path.startsWith('${AppPaths.messages}/')) return AppPaths.messages;
    if (path == AppPaths.clientVapIdEdit) return AppPaths.clientVapId;

    if (path.startsWith('/admin/')) return AppPaths.adminDashboard;
    if (path.startsWith('/lawyer/')) return AppPaths.lawyerDashboard;
    if (path.startsWith('/business/')) return AppPaths.businessDashboard;
    if (path.startsWith('/owner/')) return AppPaths.ownerDashboard;

    if (path == AppPaths.clientSettings ||
        path == AppPaths.clientSavedSearches ||
        path == AppPaths.clientSecurity ||
        path == AppPaths.clientAdvertise ||
        path == AppPaths.clientPerks ||
        path == AppPaths.profileInsights ||
        path == AppPaths.subscriptionPackages) {
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

  static String _currentLocation(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return _currentPath(context);
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

    final nearest = Navigator.of(context);
    final modalRoute = ModalRoute.of(context);

    // Dialogs, sheets and other popup routes are real local overlays. Closing
    // them must never replace the underlying GoRouter location.
    if (modalRoute is PopupRoute && nearest.canPop()) {
      nearest.pop();
      return;
    }

    // A route pushed manually with Navigator.push/PageRouteBuilder has ordinary
    // RouteSettings. Router-managed routes carry a Page as their settings.
    final isLocalPushedRoute = modalRoute != null && modalRoute.settings is! Page;
    if (isLocalPushedRoute && nearest.canPop()) {
      nearest.pop();
      return;
    }

    final currentLocation = _currentLocation(context);
    final currentPath = _currentPath(context);
    final fallback = resolvedFallback(context, fallbackPath: fallbackPath);
    final router = GoRouter.maybeOf(context);

    if (router != null) {
      // Peek without consuming first. Consuming before `router.pop()` was the
      // source of two-step Back loops: a successful pop could land on a stale
      // browser/router page while the correct app-history entry had already
      // been removed.
      final expectedPrevious = AppNavigationHistory.previousFor(currentLocation);

      if (router.canPop()) {
        final before = currentLocation;
        router.pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final after = router.routeInformationProvider.value.uri.toString();

          // If the router/browser stack disagrees with the actual page the user
          // came from, repair it immediately. This makes one Back press equal
          // one real previous screen.
          if (expectedPrevious != null &&
              expectedPrevious != before &&
              after != expectedPrevious) {
            AppNavigationHistory.consumeCurrentAndPrevious(before);
            router.go(expectedPrevious);
            return;
          }

          if (after == before) {
            final previous =
                AppNavigationHistory.consumeCurrentAndPrevious(before);
            if (previous != null && previous != before) {
              router.go(previous);
            } else if (currentPath != fallback) {
              router.go(fallback);
            }
            return;
          }

          AppNavigationHistory.reconcilePop(before: before, after: after);
        });
        return;
      }

      final previous =
          AppNavigationHistory.consumeCurrentAndPrevious(currentLocation);
      if (previous != null && previous != currentLocation) {
        router.go(previous);
        return;
      }

      if (currentPath.isNotEmpty && currentPath != fallback) {
        router.go(fallback);
        return;
      }
    }

    // Last-resort Flutter navigator fallbacks for isolated contexts without a
    // GoRouter state (tests and some locally mounted tools).
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
    final chromeVisible = ref.watch(chromeVisibilityProvider) > 0.01;
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
