import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/widgets/app_notification_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/platform_discovery_map_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/vap_id_modal.dart';
import 'package:go_router/go_router.dart';

/// Root overlay stack for VAP, map, and concierge overlays.
class OverlayModalsHost extends ConsumerStatefulWidget {
  const OverlayModalsHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OverlayModalsHost> createState() => _OverlayModalsHostState();
}

class _OverlayModalsHostState extends ConsumerState<OverlayModalsHost> {
  late final GoRouter _router;
  late String _lastRoute;

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider);

    // Do not read GoRouter.state here. This host is created above the routed
    // child, so the router can still have an empty match list during startup.
    // Reading state at that moment throws "Bad state: No element" and replaces
    // the whole web app with Flutter's grey error surface.
    _lastRoute = _router.routeInformationProvider.value.uri.toString();
    _router.routeInformationProvider.addListener(_handleRouteChange);
  }

  void _handleRouteChange() {
    // RouteInformationProvider is safe even while GoRouter is transitioning
    // between match lists; GoRouter.state is not.
    final nextRoute =
        _router.routeInformationProvider.value.uri.toString();
    if (nextRoute == _lastRoute) return;
    _lastRoute = nextRoute;
    if (!mounted) return;

    // The passport map is a global overlay above the routed page. When a map
    // preview opens its listing/profile/event route, close the overlay so the
    // destination is immediately visible instead of remaining hidden below it.
    if (ref.read(overlayModalsProvider).showPassportMap) {
      ref.read(overlayModalsProvider.notifier).closePassportMap();
    }
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_handleRouteChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modals = ref.watch(overlayModalsProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (modals.showVapId) const VapIdModal(),
        if (modals.showPassportMap)
          Positioned.fill(
            // Only the global map overlay needs an inherited GoRouter because
            // it lives beside (not under) the routed child. Keep this scope
            // local so the app itself never gets a duplicate router ancestor.
            child: InheritedGoRouter(
              goRouter: _router,
              child: PlatformDiscoveryMapScreen(
                onClose: () => ref
                    .read(overlayModalsProvider.notifier)
                    .closePassportMap(),
                showCitiesOnOpen: modals.mapShowCities,
              ),
            ),
          ),
        if (modals.showConcierge)
          Positioned.fill(
            child: ConciergeOverlay(
              initialQuery: modals.conciergeQuery,
              onClose: () =>
                  ref.read(overlayModalsProvider.notifier).closeConcierge(),
            ),
          ),
        const AppNotificationBar(),
      ],
    );
  }
}
