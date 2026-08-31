import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
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

  // PEARL/Virtual ID follows the same immersive rhythm as listings/events:
  // shared navigation appears first, then fades away after a short beat. The
  // card expands into that freed space instead of covering navigation instantly.
  Timer? _vapChromeTimer;
  bool _vapWasVisible = false;
  double _lastVapChromeOpacity = 1;
  static const _vapChromeStay = Duration(milliseconds: 2600);

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

  void _armVapChromeHide() {
    _vapChromeTimer?.cancel();
    _vapChromeTimer = Timer(_vapChromeStay, () {
      if (!mounted) return;
      if (!ref.read(overlayModalsProvider).showVapId) return;
      ref.read(chromeVisibilityProvider.notifier).hide();
    });
  }

  void _restoreUnderlyingChromePolicy() {
    final chrome = ref.read(chromeVisibilityProvider.notifier);
    final path = _router.routeInformationProvider.value.uri.path;
    chrome.suppressExplicitHide(path == AppPaths.exploreEvents);
    chrome.show();
  }

  void _syncVapChrome(bool visible, double chromeOpacity) {
    if (visible && !_vapWasVisible) {
      _vapWasVisible = true;
      _vapChromeTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !ref.read(overlayModalsProvider).showVapId) return;
        final chrome = ref.read(chromeVisibilityProvider.notifier);
        // VapIdModal used to hide chrome in initState. Override that legacy
        // behavior after the frame so users always see navigation first.
        chrome.suppressExplicitHide(false);
        chrome.show();
        _armVapChromeHide();
      });
    } else if (!visible && _vapWasVisible) {
      _vapWasVisible = false;
      _vapChromeTimer?.cancel();
      _restoreUnderlyingChromePolicy();
    }

    // If an upward scroll/edge summon reveals chrome after it was hidden,
    // automatically return to immersion after the same short hold.
    if (visible &&
        chromeOpacity >= 0.98 &&
        _lastVapChromeOpacity <= 0.08) {
      _armVapChromeHide();
    }
    _lastVapChromeOpacity = chromeOpacity;
  }

  void _summonVapChrome() {
    if (!ref.read(overlayModalsProvider).showVapId) return;
    ref.read(chromeVisibilityProvider.notifier).show();
    _armVapChromeHide();
  }

  void _handleRouteChange() {
    final nextRoute = _router.routeInformationProvider.value.uri.toString();
    if (nextRoute == _lastRoute) return;

    final previousRoute = _lastRoute;
    _lastRoute = nextRoute;
    if (!mounted) return;

    final modals = ref.read(overlayModalsProvider);

    // Virtual ID is a presentation layer, not a route. If a real route changes
    // underneath it, release the card immediately so it can never cover the
    // destination selected from the persistent app chrome.
    if (modals.showVapId) {
      ref.read(overlayModalsProvider.notifier).closeVapId();
    }

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
    _vapChromeTimer?.cancel();
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
    final chromeOpacity = ref.watch(chromeVisibilityProvider);
    _syncVapChrome(modals.showVapId, chromeOpacity);

    final mapVisible = modals.showPassportMap && !_mapHeldForDetail;
    final pauseRoutedMedia =
        mapVisible || modals.showVapId || modals.showConcierge;
    final safe = MediaQuery.paddingOf(context);

    // While chrome is visible, leave its physical touch zones exposed. As the
    // chrome fades, PEARL smoothly grows into the released space. This lets the
    // shared header/dock remain truly tappable instead of merely visible behind
    // a fullscreen modal barrier.
    final vapTop = (safe.top + 64) * chromeOpacity;
    final vapBottom = (safe.bottom + 78) * chromeOpacity;

    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: !pauseRoutedMedia,
          child: widget.child,
        ),
        if (mapVisible)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF06182B),
              child: _buildMapLayer(modals, true),
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
        if (modals.showVapId)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            top: vapTop,
            bottom: vapBottom,
            left: 0,
            right: 0,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                final h = MediaQuery.sizeOf(context).height;
                if (event.localPosition.dy <= 70 ||
                    event.localPosition.dy >= h - 96) {
                  _summonVapChrome();
                }
              },
              child: const VapIdModal(),
            ),
          ),
        const AppNotificationBar(),
      ],
    );
  }
}
