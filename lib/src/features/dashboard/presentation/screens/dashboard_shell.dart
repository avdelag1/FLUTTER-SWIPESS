import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_dock.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/guided_tour_overlay.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/providers/session_gamification_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/widgets/push_notification_prompt.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
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

  String? _lastLocation;

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

  Widget _withPersistentChromeInsets(
    BuildContext context,
    Widget child, {
    bool reserveBackRow = false,
  }) {
    final media = MediaQuery.of(context);
    final padding = media.padding;
    return MediaQuery(
      data: media.copyWith(
        padding: padding.copyWith(
          top:
              padding.top +
              _headerInset +
              (reserveBackRow ? _backRowInset : 0),
          bottom: padding.bottom + _dockInset,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (_lastLocation != location) {
      _lastLocation = location;
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

    // A MaterialPageRoute pushed from Profile/Settings lives above the shell
    // content but below this persistent header/dock. ModalRoute currentness
    // changes when that happens. Never allow shell chrome to remain interactive
    // or visible above a pushed full-screen page; restore it automatically when
    // the nested page is popped. This prevents titles/back buttons from being
    // covered even on pages that do not scroll.
    final shellRouteIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final persistentChromeVisible = showChrome && shellRouteIsCurrent;
    final showHeader = persistentChromeVisible;

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
              if (!isEvents && notification is ScrollUpdateNotification) {
                ref.read(chromeVisibilityProvider.notifier).onScroll(
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
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
                if (!isDashboard && !isEvents)
                  isProfile
                      ? widget.child
                      : _withPersistentChromeInsets(
                          context,
                          widget.child,
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
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: showHeader ? Offset.zero : const Offset(0, -0.12),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
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
              child: IgnorePointer(
                ignoring: !persistentChromeVisible,
                child: AnimatedOpacity(
                  opacity: persistentChromeVisible ? 1 : 0,
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
                      onPressed: () {
                        AppHaptics.light();
                        ref.read(chromeVisibilityProvider.notifier).show();
                        final navigator = Navigator.of(context);
                        if (navigator.canPop()) {
                          navigator.pop();
                          return;
                        }
                        context.go(AppPaths.clientDashboard);
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
                opacity: persistentChromeVisible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedSlide(
                  offset: persistentChromeVisible
                      ? Offset.zero
                      : const Offset(0, 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: SafeArea(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final subscription = ref.watch(subscriptionProvider).value;
                        return DashboardDock(
                          items: defaultDashboardNavItems,
                          selectedTab: dockSelected,
                          onTabSelected: (id) {
                            ref.read(chromeVisibilityProvider.notifier).show();

                            if (id == NavTab.filter) {
                              FilterBottomSheet.show(context);
                              return;
                            }
                            if (id == NavTab.add) {
                              context.push(AppPaths.ownerProperties);
                              return;
                            }
                            if (id == NavTab.ai) {
                              if (subscription != null &&
                                  subscription.effectiveTier.canUseAI != true) {
                                showPaywall(context, featureName: 'Swipess AI');
                                return;
                              }

                              ref.read(chromeVisibilityProvider.notifier).show();
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
                                  subscription.effectiveTier.canUseVirtualCard !=
                                      true) {
                                showPaywall(
                                  context,
                                  featureName: 'Virtual ID Card',
                                );
                                return;
                              }
                              ref.read(overlayModalsProvider.notifier).openVapId();
                              return;
                            }
                            if (id == NavTab.events &&
                                subscription != null &&
                                subscription.effectiveTier.canViewEvents != true) {
                              showPaywall(context, featureName: 'Events');
                              return;
                            }
                            if (id == NavTab.legal &&
                                subscription != null &&
                                subscription.effectiveTier.canViewEvents != true) {
                              showPaywall(context, featureName: 'Legal services');
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
