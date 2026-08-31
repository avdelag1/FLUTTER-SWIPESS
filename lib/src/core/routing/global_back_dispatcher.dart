import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_navigation_history.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/routing/section_navigation.dart';

/// Global Android/system Back behavior.
///
/// Priority:
/// 1. Close the active overlay when Back belongs to that overlay.
/// 2. Pop a genuine pushed route and preserve its exact widget state.
/// 3. For routes reached with `go()`, return to recorded real navigation
///    history rather than guessing Dashboard.
/// 4. Use the static section hierarchy only as a final safety fallback.
class GlobalBackButtonDispatcher extends RootBackButtonDispatcher {
  GlobalBackButtonDispatcher({required this.router, required this.ref});

  final GoRouter router;
  final Ref ref;

  @override
  Future<bool> didPopRoute() async {
    final modals = ref.read(overlayModalsProvider);
    final before = _currentLocation();
    final previous = AppNavigationHistory.previousFor(before);

    // The map overlay deliberately stays mounted while a pushed listing, event,
    // or profile detail is visible. In that state Back belongs to the detail
    // route first; closing the map would lose the user's map context.
    if (modals.showPassportMap && _isMapDetailRoute(_currentPath())) {
      if (await super.didPopRoute()) {
        _verifyPop(before: before, previous: previous);
        return true;
      }
    }

    // Closing PEARL/AI/Map is not navigation. Never consume route history for
    // this action; the following Back press must still return to the real page
    // the user was on before the current route.
    if (_closeOpenOverlay()) return true;

    if (await super.didPopRoute()) {
      _verifyPop(before: before, previous: previous);
      return true;
    }

    if (previous != null && previous != before) {
      AppNavigationHistory.consumeCurrentAndPrevious(before);
      router.go(previous);
      return true;
    }

    final parent = SectionNavigation.parentRoute(_currentPath());
    if (parent == null) return false;
    AppNavigationHistory.consumeCurrentAndPrevious(before);
    router.go(parent);
    return true;
  }

  void _verifyPop({required String before, required String? previous}) {
    // Browser/PWA-backed navigators can claim a successful pop while a redirect
    // resolves straight back to the same URI. Repair that case after routing has
    // settled so Android Back never feels dead or jumps unexpectedly Dashboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final after = _currentLocation();
      if (after == before) {
        if (previous != null && previous != before) {
          AppNavigationHistory.consumeCurrentAndPrevious(before);
          router.go(previous);
        }
        return;
      }
      AppNavigationHistory.reconcilePop(before: before, after: after);
    });
  }

  bool _isMapDetailRoute(String route) {
    return route.startsWith('/listing/') ||
        route.startsWith('/profile/') ||
        route.startsWith('/explore/events/') ||
        route.startsWith('/preview/listing/') ||
        route.startsWith('/preview/profile/');
  }

  bool _closeOpenOverlay() {
    final modals = ref.read(overlayModalsProvider);
    if (!modals.showVapId && !modals.showPassportMap && !modals.showConcierge) {
      return false;
    }
    ref.read(overlayModalsProvider.notifier).closeAll();
    return true;
  }

  String _currentPath() {
    try {
      return router.state.uri.path;
    } catch (_) {
      return '/';
    }
  }

  String _currentLocation() {
    try {
      return router.routeInformationProvider.value.uri.toString();
    } catch (_) {
      return _currentPath();
    }
  }
}

final globalBackButtonDispatcherProvider = Provider<GlobalBackButtonDispatcher>(
  (ref) {
    return GlobalBackButtonDispatcher(
      router: ref.watch(appRouterProvider),
      ref: ref,
    );
  },
);
