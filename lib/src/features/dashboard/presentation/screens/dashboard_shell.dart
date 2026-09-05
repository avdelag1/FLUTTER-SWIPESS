import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/motion/ios_motion.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/header_menu_open_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_route_actions.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_dock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/guided_tour_overlay.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/providers/session_gamification_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/widgets/push_notification_prompt.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/session/domain/app_market_context.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/chrome_summon_zones.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';
import 'package:go_router/go_router.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  static const _headerInset = 88.0;
  static const _dockInset = 82.0;
  static const _dismissThreshold = 120.0;

  String? _lastLocation;
  double _eventsSwipeOffset = 0;
  final TextEditingController _dashboardSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // App-wide engagement tracking is already owned by
    // _EngagementTrackingBootstrap. DashboardShell must not register a second
    // client and then touch Riverpod ref while it is being disposed.
  }

  @override
  void dispose() {
    _dashboardSearchController.dispose();
    super.dispose();
  }

  void _dismissEventsWithSwipe() {
    AppHaptics.medium();
    setState(() => _eventsSwipeOffset = 0);
    final chrome = ref.read(chromeVisibilityProvider.notifier);
    chrome.suppressExplicitHide(false);
    chrome.show();
    context.go(AppPaths.clientDashboard);
  }

  void _openAiListingBuilder(BuildContext context) {
    AppHaptics.medium();
    ref.read(overlayModalsProvider.notifier).closeAll();
    ref.read(chromeVisibilityProvider.notifier).show();
    AppRouteActions.openAiListingBuilder(context);
  }

  Widget _withPersistentChromeInsets(BuildContext context, Widget child) {
    final media = MediaQuery.of(context);
    final padding = media.padding;
    final topInset = padding.top + _headerInset;
    final bottomInset = padding.bottom + _dockInset;

    return Padding(
      padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (_lastLocation != location) {
      _lastLocation = location;
      LiveVoiceInput.instance.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final chrome = ref.read(chromeVisibilityProvider.notifier);
        // Paint the real app navigation first on every shell destination.
        // EventsScreen owns the later timed immersive hide, so route entry must
        // never force Events hidden before the user has seen the header + dock.
        chrome.suppressExplicitHide(false);
        chrome.show();
      });
    }

    final isDashboard =
        location == AppPaths.clientDashboard ||
        location == AppPaths.legacyDashboard;
    final isProfile =
        location == AppPaths.clientProfile || location == AppPaths.ownerProfile;
    final isEvents = location == AppPaths.exploreEvents;
    final isLikes =
        location == AppPaths.clientLikedProperties ||
        location == AppPaths.ownerLikedClients;
    // These shell-owned root pages deliberately rely on the shared header/dock.
    // Reserve that space centrally so their own title/search rows never render
    // underneath the floating app chrome on Android, iOS, or PWA.
    final needsPersistentChromeInsets =
        isLikes ||
        location == AppPaths.messages ||
        location == AppPaths.exploreSeekers;

    final routeTab = AppPaths.tabForLocation(location);
    final currentTab = routeTab ?? ref.watch(navTabProvider);
    final user = ref.watch(currentUserProvider);

    if (routeTab != null && ref.read(navTabProvider) != routeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(navTabProvider) != routeTab) {
          ref.read(navTabProvider.notifier).set(routeTab);
        }
      });
    }

    final profile = ref.watch(currentProfileProvider).value;
    final isLight = ref.watch(isLightThemeProvider);
    final chromeOpacity = ref.watch(chromeVisibilityProvider);
    final overlays = ref.watch(overlayModalsProvider);
    final shellRouteIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final headerMenuOpen = ref.watch(headerMenuOpenProvider);
    // The provider is the single source of truth for the real app header/dock.
    // EventsScreen toggles this provider together with its local event controls,
    // which keeps the card resize and the global chrome perfectly synchronized.
    final persistentChromeVisible =
        chromeOpacity > 0.01 && (shellRouteIsCurrent || headerMenuOpen);
    final showHeader = persistentChromeVisible;
    final chromeMotionDuration = IosMotion.fast;

    final dockSelected = overlays.showVapId
        ? NavTab.idCard
        : overlays.showConcierge
        ? NavTab.ai
        : currentTab;
    final canvas = AppTheme.canvasFor(isLight: isLight);

    return Scaffold(
      backgroundColor: canvas,
      extendBody: true,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Every scrollable shell page speaks the same chrome language:
              // scroll down to clear the view; scroll up to summon navigation.
              if (!isEvents &&
                  notification.depth == 0 &&
                  notification.metrics.axis == Axis.vertical &&
                  notification is ScrollUpdateNotification) {
                ref
                    .read(chromeVisibilityProvider.notifier)
                    .onScroll(
                      pixels: notification.metrics.pixels,
                      delta: notification.scrollDelta ?? 0,
                    );
              }
              return false;
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: !isDashboard,
                  child: TickerMode(
                    enabled: isDashboard,
                    child: const BentoDashboardScreen(),
                  ),
                ),
                if (isEvents)
                  TweenAnimationBuilder<double>(
                    key: const ValueKey('events-panel'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) => Transform.translate(
                      offset: Offset(0, 22 * (1 - progress)),
                      child: Opacity(opacity: progress, child: child),
                    ),
                    child: GestureDetector(
                      onVerticalDragUpdate: (details) {
                        if (details.delta.dy > 0) {
                          setState(() {
                            _eventsSwipeOffset =
                                (_eventsSwipeOffset + details.delta.dy).clamp(
                                  0,
                                  320,
                                );
                          });
                        }
                      },
                      onVerticalDragEnd: (details) {
                        if (_eventsSwipeOffset >= _dismissThreshold ||
                            (details.primaryVelocity ?? 0) > 800) {
                          _dismissEventsWithSwipe();
                        } else {
                          setState(() => _eventsSwipeOffset = 0);
                        }
                      },
                      onVerticalDragCancel: () =>
                          setState(() => _eventsSwipeOffset = 0),
                      child: Transform.translate(
                        offset: Offset(0, _eventsSwipeOffset),
                        child: Opacity(
                          opacity: (1 - (_eventsSwipeOffset / 420)).clamp(
                            .55,
                            1,
                          ),
                          // Events is a true reels surface. It fills the complete
                          // viewport; shared chrome floats above it until EventsScreen hides it.
                          child: const EventsScreen(),
                        ),
                      ),
                    ),
                  ),
                if (!isDashboard && !isEvents)
                  needsPersistentChromeInsets
                      ? _withPersistentChromeInsets(
                          context,
                          IosMotion.crossFade(
                            key: location,
                            child: widget.child,
                          ),
                        )
                      : IosMotion.crossFade(key: location, child: widget.child),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: showHeader ? chromeOpacity : 0,
              duration: chromeMotionDuration,
              curve: IosMotion.enter,
              child: AnimatedSlide(
                offset: showHeader
                    ? Offset(0, -0.12 * (1.0 - chromeOpacity))
                    : const Offset(0, -0.12),
                duration: chromeMotionDuration,
                curve: IosMotion.enter,
                child: IgnorePointer(
                  ignoring: !showHeader,
                  child: AppTopBar(
                    firstName: profile?.name.split(' ').first,
                    avatarUrl: profile?.avatarUrl,
                    searchBar: GlowSearchBar(
                      controller: _dashboardSearchController,
                      hint: 'What are you looking for?',
                      compactHeader: true,
                    ),
                    onProfileTap: () {
                      AppHaptics.light();
                      ref.read(overlayModalsProvider.notifier).closeAll();
                      ref.read(chromeVisibilityProvider.notifier).show();
                      context.go(AppPaths.clientProfile);
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !persistentChromeVisible,
              child: AnimatedOpacity(
                opacity: persistentChromeVisible ? chromeOpacity : 0,
                duration: chromeMotionDuration,
                curve: IosMotion.enter,
                child: AnimatedSlide(
                  offset: persistentChromeVisible
                      ? Offset(0, 1.0 * (1.0 - chromeOpacity))
                      : const Offset(0, 1.0),
                  duration: chromeMotionDuration,
                  curve: IosMotion.enter,
                  child: SafeArea(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final subscription = ref
                            .watch(subscriptionProvider)
                            .value;
                        final market = ref.watch(appMarketProvider).value;
                        final dockItems = defaultDashboardNavItems
                            .where(
                              (item) => _dockFeatureEnabled(market, item.id),
                            )
                            .toList(growable: false);
                        return DashboardDock(
                          items: dockItems,
                          selectedTab: dockSelected,
                          onTabSelected: (id) {
                            final chrome = ref.read(
                              chromeVisibilityProvider.notifier,
                            );
                            // Every dock interaction restores chrome first. The
                            // Virtual ID then owns when it auto-hides again.
                            chrome.show();

                            // PEARL never gets to trap the user. Any other dock
                            // choice immediately releases it before processing
                            // the destination tap.
                            if (overlays.showVapId && id != NavTab.idCard) {
                              ref
                                  .read(overlayModalsProvider.notifier)
                                  .closeVapId();
                            }

                            final feature = _featureForTab(id);
                            if (feature != null &&
                                market != null &&
                                (!market.effectiveOpen ||
                                    !market.featureEnabled(feature))) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This module is not active in your current SWIPESS market.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (id == NavTab.filter) {
                              ref
                                  .read(overlayModalsProvider.notifier)
                                  .closeAll();
                              FilterBottomSheet.show(context);
                              return;
                            }
                            if (id == NavTab.add) {
                              _openAiListingBuilder(context);
                              return;
                            }
                            if (id == NavTab.ai) {
                              if (subscription != null &&
                                  subscription.effectiveTier.canUseAI != true) {
                                showPaywall(context, featureName: 'SWIPESS AI');
                                return;
                              }
                              if (overlays.showConcierge) {
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .closeConcierge();
                              } else {
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .openConcierge();
                              }
                              return;
                            }
                            if (id == NavTab.idCard) {
                              if (subscription != null &&
                                  subscription
                                          .effectiveTier
                                          .canUseVirtualCard !=
                                      true) {
                                showPaywall(
                                  context,
                                  featureName: 'Virtual ID Card',
                                );
                                return;
                              }
                              if (overlays.showVapId) {
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .closeVapId();
                              } else {
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .openVapId();
                              }
                              return;
                            }
                            if (id == NavTab.events &&
                                subscription != null &&
                                subscription.effectiveTier.canViewEvents !=
                                    true) {
                              showPaywall(context, featureName: 'Events');
                              return;
                            }
                            if (id == NavTab.legal &&
                                subscription != null &&
                                subscription.effectiveTier.canUseLegal !=
                                    true) {
                              showPaywall(
                                context,
                                featureName: 'Legal services',
                              );
                              return;
                            }

                            ref.read(overlayModalsProvider.notifier).closeAll();

                            if (id == NavTab.dashboard &&
                                dockSelected == NavTab.dashboard) {
                              ref
                                  .read(dashboardHomeTappedProvider.notifier)
                                  .state++;
                            } else {
                              ref.read(navTabProvider.notifier).set(id);
                              context.go(AppPaths.pathForTab(id));
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          ChromeSummonZones(
            // `visible: true` disables the zones. Only arm them on immersive
            // surfaces where chrome is allowed to auto-hide.
            visible:
                isEvents ||
                persistentChromeVisible ||
                isProfile ||
                !_chromeMayAutoHide(location),
            onSummon: () {
              if (shellRouteIsCurrent) {
                ref.read(chromeVisibilityProvider.notifier).show();
              }
            },
          ),
          const PushNotificationPrompt(enabled: false),
          GuidedTourOverlay(
            enabled: user != null && shellRouteIsCurrent,
            userId: user?.id,
            userCreatedAt: user?.createdAt,
          ),
        ],
      ),
    );
  }
}

String? _featureForTab(NavTab tab) => switch (tab) {
  NavTab.ai => 'ai',
  NavTab.idCard => 'local_id',
  NavTab.seekers => 'seekers',
  NavTab.legal => 'legal',
  NavTab.events => 'events',
  _ => null,
};

bool _dockFeatureEnabled(AppMarketContext? market, NavTab tab) {
  final feature = _featureForTab(tab);
  if (feature == null || market == null) return true;
  return market.effectiveOpen && market.featureEnabled(feature);
}

/// Routes where scroll may fade the header/dock. Everything else keeps chrome
/// sticky so profile/tools buttons stay tappable.
bool _chromeMayAutoHide(String location) {
  return location == AppPaths.clientDashboard ||
      location == AppPaths.legacyDashboard ||
      location == AppPaths.exploreEvents ||
      location == AppPaths.clientLikedProperties ||
      location == AppPaths.ownerLikedClients ||
      location.startsWith('/listing/');
}
