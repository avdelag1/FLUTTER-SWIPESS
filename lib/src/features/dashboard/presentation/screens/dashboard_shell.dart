import 'dart:ui';

import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/motion/ios_motion.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
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
import 'package:go_router/go_router.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  static const _headerInset = 72.0;
  static const _dockInset = 82.0;
  static const _backRowInset = 44.0;
  static const _dismissThreshold = 120.0; // px of downward pull to dismiss

  String? _lastLocation;
  double _eventsSwipeOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionGamificationProvider).startTracking(context);
    });
  }

  @override
  void dispose() {
    ref.read(sessionGamificationProvider).stopTracking();
    super.dispose();
  }

  void _dismissEventsWithSwipe() {
    AppHaptics.medium();
    setState(() => _eventsSwipeOffset = 0);
    ref.read(chromeVisibilityProvider.notifier).show();
    context.go(AppPaths.clientDashboard);
  }

  /// Reserve real layout space for persistent header/dock chrome.
  ///
  /// Previously this only changed MediaQuery.padding. Any child that used fixed
  /// padding or a Scaffold without SafeArea could still render underneath the
  /// floating header. Physical padding makes the no-overlap contract global.
  Widget _withPersistentChromeInsets(
    BuildContext context,
    Widget child, {
    bool reserveBackRow = false,
  }) {
    final media = MediaQuery.of(context);
    final padding = media.padding;
    final topInset =
        padding.top + _headerInset + (reserveBackRow ? _backRowInset : 0);
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

  void _goBackOrDashboard() {
    ref.read(chromeVisibilityProvider.notifier).show();
    NavBack.popOrGo(context, fallbackPath: AppPaths.clientDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (_lastLocation != location) {
      _lastLocation = location;
      // Auto-cancel microphone any time the user navigates to a new page
      LiveVoiceInput.instance.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(chromeVisibilityProvider.notifier).show();
      });
    }

    final isDashboard =
        location == AppPaths.clientDashboard ||
        location == AppPaths.legacyDashboard;
    final isProfile = location == AppPaths.clientProfile;
    final isEvents = location == AppPaths.exploreEvents;
    final isLikes = location == AppPaths.clientLikedProperties;
    final isSeekers = location == AppPaths.exploreSeekers;

    final showShellBack = isLikes || isSeekers;

    final routeTab = AppPaths.tabForLocation(location);
    final currentTab = routeTab ?? ref.watch(navTabProvider);
    final user = ref.watch(currentUserProvider);

    if (routeTab != null && ref.read(navTabProvider) != routeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(navTabProvider) != routeTab) {
          ref.read(navTabProvider.notifier).set(routeTab);
        }
      });
    }

    final profile = ref.watch(currentProfileProvider).value;
    final isLight = ref.watch(isLightThemeProvider);
    final showChrome = ref.watch(chromeVisibilityProvider);

    final shellRouteIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    // Profile is a navigation hub — keep header and dock visible while browsing it.
    final persistentChromeVisible = isProfile
        ? shellRouteIsCurrent
        : (showChrome && shellRouteIsCurrent);
    final showHeader = persistentChromeVisible;
    // Events deliberately inherits the exact swipe-deck chrome cadence:
    // reveal in 360ms, hide in 500ms, same cubic curve and slide vectors.
    final chromeMotionDuration = isEvents
        ? Duration(milliseconds: persistentChromeVisible ? 120 : 150)
        : IosMotion.fast;

    final overlays = ref.watch(overlayModalsProvider);
    final dockSelected = overlays.showVapId
        ? NavTab.idCard
        : overlays.showConcierge
        ? NavTab.ai
        : currentTab;
    final canvas = AppTheme.canvasFor(isLight: isLight);
    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: canvas,
      extendBody: true,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!isEvents &&
                  !isProfile &&
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
                    duration: const Duration(milliseconds: 110),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) => Transform.translate(
                      offset: Offset(0, 28 * (1 - progress)),
                      child: Opacity(opacity: progress, child: child),
                    ),
                    child: GestureDetector(
                      onVerticalDragUpdate: (details) {
                        // Only track downward drag — upward scroll belongs to
                        // the events screen's own ScrollView.
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
                          // Snap back with spring-like animation.
                          setState(() => _eventsSwipeOffset = 0);
                        }
                      },
                      onVerticalDragCancel: () {
                        setState(() => _eventsSwipeOffset = 0);
                      },
                      child: _eventsSwipeOffset == 0
                          ? AnimatedContainer(
                              duration: chromeMotionDuration,
                              curve: Curves.easeOutCubic,
                              margin: persistentChromeVisible
                                  ? EdgeInsets.fromLTRB(
                                      8,
                                      safe.top + 58,
                                      8,
                                      safe.bottom + 70,
                                    )
                                  : EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(
                                  persistentChromeVisible ? 24 : 0,
                                ),
                              ),
                              child: const EventsScreen(),
                            )
                          : Transform.translate(
                              offset: Offset(0, _eventsSwipeOffset),
                              child: Opacity(
                                // Fade out slightly as user pulls down, like Instagram.
                                opacity: (1 - (_eventsSwipeOffset / 320)).clamp(
                                  0.4,
                                  1.0,
                                ),
                                child: AnimatedContainer(
                                  duration: chromeMotionDuration,
                                  curve: Curves.easeOutCubic,
                                  margin: persistentChromeVisible
                                      ? EdgeInsets.fromLTRB(
                                          8,
                                          safe.top + 58,
                                          8,
                                          safe.bottom + 70,
                                        )
                                      : EdgeInsets.zero,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(
                                      persistentChromeVisible ? 24 : 0,
                                    ),
                                  ),
                                  child: const EventsScreen(),
                                ),
                              ),
                            ),
                    ),
                  ),
                if (!isDashboard && !isEvents)
                  isProfile
                      ? IosMotion.crossFade(key: location, child: widget.child)
                      : _withPersistentChromeInsets(
                          context,
                          IosMotion.crossFade(
                            key: location,
                            child: widget.child,
                          ),
                          reserveBackRow: showShellBack,
                        ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: showHeader ? 1 : 0,
              duration: chromeMotionDuration,
              curve: IosMotion.enter,
              child: AnimatedSlide(
                offset: showHeader ? Offset.zero : const Offset(0, -0.12),
                duration: chromeMotionDuration,
                curve: IosMotion.enter,
                child: IgnorePointer(
                  ignoring: !showHeader,
                  child: AppTopBar(
                    firstName: profile?.name.split(' ').first,
                    avatarUrl: profile?.avatarUrl,
                    onProfileTap: () {
                      AppHaptics.light();
                      ref.read(chromeVisibilityProvider.notifier).show();
                      context.go(AppPaths.clientProfile);
                    },
                  ),
                ),
              ),
            ),
          ),
          if (showShellBack)
            Positioned(
              top: MediaQuery.paddingOf(context).top + _headerInset,
              left: 16,
              child: AnimatedOpacity(
                opacity: persistentChromeVisible ? 1 : 0.72,
                duration: const Duration(milliseconds: 180),
                child: Material(
                  color: isLight ? Colors.white : const Color(0xFF111111),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: isLight
                          ? Colors.black.withAlpha(22)
                          : Colors.white.withAlpha(32),
                    ),
                  ),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    iconSize: 18,
                    color: isLight ? Colors.black : Colors.white,
                    onPressed: _goBackOrDashboard,
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
                opacity: persistentChromeVisible ? 1 : 0,
                duration: chromeMotionDuration,
                curve: IosMotion.enter,
                child: AnimatedSlide(
                  offset: persistentChromeVisible
                      ? Offset.zero
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
                            ref.read(chromeVisibilityProvider.notifier).show();

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
                              FilterBottomSheet.show(context);
                              return;
                            }
                            if (id == NavTab.add) {
                              AppHaptics.medium();
                              showCreateListingChooser(context);
                              return;
                            }
                            if (id == NavTab.ai) {
                              if (subscription != null &&
                                  subscription.effectiveTier.canUseAI != true) {
                                showPaywall(
                                  context,
                                  featureName: 'Google Gemini',
                                );
                                return;
                              }

                              ref
                                  .read(chromeVisibilityProvider.notifier)
                                  .show();
                              if (overlays.showConcierge) {
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .closeConcierge();
                                return;
                              }
                              ref
                                  .read(overlayModalsProvider.notifier)
                                  .openConcierge();
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
                              ref
                                  .read(overlayModalsProvider.notifier)
                                  .openVapId();
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

                            ref.read(navTabProvider.notifier).set(id);
                            context.go(AppPaths.pathForTab(id));
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!isEvents)
            ChromeSummonZones(
              visible: persistentChromeVisible,
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
