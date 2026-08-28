import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/routing/section_navigation.dart';

/// Port of Cap `useGlobalBackButton` — the Android hardware Back key.
///
/// Cap intercepted it to close overlays first and then walk up the hierarchy.
/// Flutter had no equivalent, and because almost every Swipess destination is
/// reached with `context.go` (which replaces the stack rather than pushing),
/// the root navigator usually had nothing to pop: one Back press from Settings,
/// Documents or a section page **closed the app**.
///
/// Order of handling, matching Cap:
/// 1. An open overlay (PEARL / Passport map / Concierge) closes and eats the press.
/// 2. A real pushed route pops, so pushed detail screens still behave natively.
/// 3. Otherwise walk up: sub-page → section home → dashboard.
/// 4. On a dashboard root or a pre-auth screen the press falls through to the
///    platform, which is Cap's `App.exitApp()`.
class GlobalBackButtonDispatcher extends RootBackButtonDispatcher {
  GlobalBackButtonDispatcher({required this.router, required this.ref});

  final GoRouter router;
  final Ref ref;

  @override
  Future<bool> didPopRoute() async {
    final modals = ref.read(overlayModalsProvider);

    // The map overlay deliberately stays mounted while a pushed listing, event,
    // or profile detail is visible. In that state Back belongs to the detail
    // route first; closing the overlay first loses the user's map context and
    // makes the next screen look like a jump to Dashboard.
    if (modals.showPassportMap && _isMapDetailRoute(_currentLocation())) {
      if (await super.didPopRoute()) return true;
    }

    if (_closeOpenOverlay()) return true;
    if (await super.didPopRoute()) return true;

    final parent = SectionNavigation.parentRoute(_currentLocation());
    if (parent == null) return false;
    router.go(parent);
    return true;
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

  String _currentLocation() {
    try {
      return router.state.uri.path;
    } catch (_) {
      // No match resolved yet (very early boot) — treat as the gate.
      return '/';
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
