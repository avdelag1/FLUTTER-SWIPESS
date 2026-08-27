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

  // When a user opens a listing/profile/event from Map, keep the actual Map
  // widget alive offstage instead of destroying it. Going Back then reveals the
  // same camera, pins, filters, selected preview and already-loaded provider data
  // instantly. This also guarantees the world intro is never replayed simply
  // because the user inspected a result.
  bool _mapHeldForDetail = false;
  String? _mapReturnRoute;

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

  bool _isMapDetailRoute(String route) {
    final path = Uri.tryParse(route)?.path ?? route;
    return path.startsWith('/listing/') ||
        path.startsWith('/profile/') ||
        path.startsWith('/explore/events/') ||
        path.startsWith('/preview/listing/') ||
        path.startsWith('/preview/profile/');
  }

  void _handleRouteChange() {
    // RouteInformationProvider is safe even while GoRouter is transitioning
    // between match lists; GoRouter.state is not.
    final nextRoute = _router.routeInformationProvider.value.uri.toString();
    if (nextRoute == _lastRoute) return;

    final previousRoute = _lastRoute;
    _lastRoute = nextRoute;
    if (!mounted) return;

    final modals = ref.read(overlayModalsProvider);

    if (modals.showPassportMap) {
      // Preview navigation is special: hide the map visually, but keep it
      // mounted. Back navigation restores this exact live instance.
      if (_isMapDetailRoute(nextRoute)) {
        setState(() {
          _mapHeldForDetail = true;
          _mapReturnRoute = previousRoute;
        });
      } else {
        setState(() {
          _mapHeldForDetail = false;
          _mapReturnRoute = null;
        });
      }
      ref.read(overlayModalsProvider.notifier).closePassportMap();
      return;
    }

    if (_mapHeldForDetail) {
      if (nextRoute == _mapReturnRoute) {
        // User pressed Back from the detail/insight page: reveal the already
        // mounted map immediately, with no re-fetch and no intro replay.
        setState(() {
          _mapHeldForDetail = false;
          _mapReturnRoute = null;
        });
        ref.read(overlayModalsProvider.notifier).openPassportMap();
        return;
      }

      // If the user leaves the detail flow for another unrelated destination,
      // release the preserved map instead of keeping a hidden screen forever.
      if (!_isMapDetailRoute(nextRoute)) {
        setState(() {
          _mapHeldForDetail = false;
          _mapReturnRoute = null;
        });
      }
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
    final keepMapAlive = modals.showPassportMap || _mapHeldForDetail;
    final pauseRoutedMedia = modals.showPassportMap ||
        modals.showVapId ||
        modals.showConcierge;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The dashboard/detail route stays mounted under global overlays, but
        // its tickers are paused while hidden. Dashboard video widgets already
        // observe TickerMode, so this stops invisible decoding/playback under
        // Map and avoids wasting GPU/VideoFrame resources in Chrome.
        TickerMode(
          enabled: !pauseRoutedMedia,
          child: widget.child,
        ),
        if (modals.showVapId) const VapIdModal(),
        if (keepMapAlive)
          Positioned.fill(
            child: Offstage(
              offstage: !modals.showPassportMap,
              child: TickerMode(
                enabled: modals.showPassportMap,
                // Only the global map overlay needs an inherited GoRouter
                // because it lives beside (not under) the routed child.
                child: InheritedGoRouter(
                  goRouter: _router,
                  child: PlatformDiscoveryMapScreen(
                    onClose: () {
                      setState(() {
                        _mapHeldForDetail = false;
                        _mapReturnRoute = null;
                      });
                      ref
                          .read(overlayModalsProvider.notifier)
                          .closePassportMap();
                    },
                    showCitiesOnOpen: modals.mapShowCities,
                  ),
                ),
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
