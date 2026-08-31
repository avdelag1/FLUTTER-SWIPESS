import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_navigation_history.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

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

    if (path == AppPaths.clientSettings ||
        path == AppPaths.clientSavedSearches ||
        path == AppPaths.clientSecurity ||
        path == AppPaths.clientAdvertise ||
        path == AppPaths.clientPerks ||
        path == AppPaths.clientMaintenance ||
        path == AppPaths.profileInsights ||
        path == AppPaths.subscriptionPackages ||
        path == AppPaths.exploreIntel ||
        path == AppPaths.explorePrices ||
        path == AppPaths.exploreTours ||
        path == AppPaths.exploreRoommates ||
        path == AppPaths.clientServices ||
        path == AppPaths.clientContracts ||
        path == AppPaths.clientLegal ||
        path == AppPaths.clientLegalServices ||
        path == AppPaths.documents ||
        path == AppPaths.escrow ||
        path == AppPaths.notifications ||
        path == AppPaths.validateId) {
      return AppPaths.clientProfile;
    }

    if (path == AppPaths.ownerSettings ||
        path == AppPaths.ownerSavedSearches ||
        path == AppPaths.ownerSecurity ||
        path == AppPaths.ownerInterestedClients ||
        path == AppPaths.ownerProperties ||
        path == AppPaths.ownerListings) {
      return AppPaths.ownerProfile;
    }

    if (path.startsWith('/admin/')) return AppPaths.adminDashboard;
    if (path.startsWith('/lawyer/')) return AppPaths.lawyerDashboard;
    if (path.startsWith('/business/')) return AppPaths.businessDashboard;
    if (path.startsWith('/owner/')) return AppPaths.ownerDashboard;

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

    if (modalRoute is PopupRoute && nearest.canPop()) {
      nearest.pop();
      return;
    }

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
      final expectedPrevious = AppNavigationHistory.previousFor(currentLocation);

      if (router.canPop()) {
        final before = currentLocation;
        router.pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final after = router.routeInformationProvider.value.uri.toString();
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = _currentPath(context);
    final modalRoute = ModalRoute.of(context);
    final routerManaged = modalRoute != null && modalRoute.settings is Page;

    // Router-managed signed-in pages already have one shared Back control in
    // the persistent app chrome. Hiding page-level CapBackButtons here avoids
    // the old two-stage experience where Back revealed a second Back button on
    // what looked like the same page. Locally pushed full-screen tools keep
    // their own Back because they cover the shell chrome.
    if (onTap == null && routerManaged && AppPaths.isShellLocation(path)) {
      return const SizedBox.shrink();
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final followsChrome =
        path == AppPaths.clientProfile || path == AppPaths.ownerProfile;
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
