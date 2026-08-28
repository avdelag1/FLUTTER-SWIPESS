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

  // Opening a result from Map must not destroy or close the map overlay. We
  // simply hold the exact live instance offstage while the routed detail page is
  // visible, then reveal it again on Back. Camera, pins, filters, tray, search
  // and selected preview therefore remain exactly where the user left them.
  bool _mapHeldForDetail = false;
  String? _mapReturnRoute;

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider);
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
    final nextRoute = _router.routeInformationProvider.value.uri.toString();
    if (nextRoute == _lastRoute) return;

    final previousRoute = _lastRoute;
    _lastRoute = nextRoute;
    if (!mounted) return;

    final modals = ref.read(overlayModalsProvider);

    if (modals.showPassportMap && !_mapHeldForDetail) {
      // A listing/profile/event was pushed from the live map. Keep
      // showPassportMap=true: changing that provider here caused a close/open
      // race that could make the detail page appear briefly and then bounce
      // straight back to Map. Only hide the map visually.
      if (_isMapDetailRoute(nextRoute)) {
        setState(() {
          _mapHeldForDetail = true;
          _mapReturnRoute = previousRoute;
        });
      }
      return;
    }

    if (!_mapHeldForDetail) return;

    if (nextRoute == _mapReturnRoute) {
      // Back from detail: no provider toggle, no reconstruction, no refetch.
      // Reveal the exact same mounted map instance immediately.
      setState(() {
        _mapHeldForDetail = false;
        _mapReturnRoute = null;
      });
      return;
    }

    if (!_isMapDetailRoute(nextRoute)) {
      // The user intentionally navigated away from the detail/map flow. Release
      // the preserved overlay so it cannot unexpectedly reappear later.
      setState(() {
        _mapHeldForDetail = false;
        _mapReturnRoute = null;
      });
      if (modals.showPassportMap) {
        ref.read(overlayModalsProvider.notifier).closePassportMap();
      }
    }
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_handleRouteChange);
    super.dispose();
  }

  Widget _buildMapLayer(OverlayModals modals, bool mapVisible) {
    return IgnorePointer(
      ignoring: !mapVisible,
      child: TickerMode(
        enabled: mapVisible,
        child: InheritedGoRouter(
          goRouter: _router,
          child: PlatformDiscoveryMapScreen(
            onClose: () {
              setState(() {
                _mapHeldForDetail = false;
                _mapReturnRoute = null;
              });
              ref.read(overlayModalsProvider.notifier).closePassportMap();
            },
            showCitiesOnOpen: modals.mapShowCities,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modals = ref.watch(overlayModalsProvider);
    final keepMapAlive = modals.showPassportMap || _mapHeldForDetail;
    final mapVisible = modals.showPassportMap && !_mapHeldForDetail;
    final pauseRoutedMedia = mapVisible ||
        modals.showVapId ||
        modals.showConcierge;

    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: !pauseRoutedMedia,
          child: widget.child,
        ),
        if (modals.showVapId) const VapIdModal(),
        if (keepMapAlive)
          Positioned.fill(
            // Paint the modal surface before Mapbox attaches. This prevents
            // the dashboard's light frame and horizontal tray shadow flashing
            // through during the first native/web map frame.
            child: ColoredBox(
              color: const Color(0xFF06182B),
              child: _mapHeldForDetail
                  ? Offstage(
                      offstage: true,
                      child: _buildMapLayer(modals, mapVisible),
                    )
                  : AnimatedOpacity(
                      opacity: mapVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: _buildMapLayer(modals, mapVisible),
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
