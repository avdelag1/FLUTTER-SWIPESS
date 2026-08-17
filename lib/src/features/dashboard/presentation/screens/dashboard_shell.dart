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

  bool _eventsMounted = false;
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

  Widget _withPersistentChromeInsets(BuildContext context, Widget child) {
    final media = MediaQuery.of(context);
    final padding = media.padding;
    return MediaQuery(
      data: media.copyWith(
        padding: padding.copyWith(
          top: padding.top + _headerInset,
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
    if (isEvents) _eventsMounted = true;

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

    // The shared header is a primary navigation surface, not decoration.
    // Keep it available on every route rendered by this shell.
    final showHeader = showChrome;

    final overlays = ref.watch(overlayModalsProvider);
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
              if (notification is ScrollUpdateNotification) {
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
                if (_eventsMounted)
                  Offstage(
                    offstage: !isEvents,
                    child: TickerMode(
                      enabled: isEvents,
                      child: _withPersistentChromeInsets(
                        context,
                        const EventsScreen(),
                      ),
                    ),
                  ),
                if (!isDashboard && !isEvents)
                  isProfile
                      ? widget.child
                      : _withPersistentChromeInsets(context, widget.child),
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
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !showChrome,
              child: AnimatedOpacity(
                opacity: showChrome ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedSlide(
                  offset: showChrome ? Offset.zero : const Offset(0, 1.0),
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
                              if (subscription?.effectiveTier.canUseAI != true) {
                                showPaywall(context, featureName: 'Swipess AI');
                                return;
                              }
                              if (overlays.showConcierge) {
                                ref.read(chromeVisibilityProvider.notifier).hide();
                                return;
                              }
                              ref
                                  .read(overlayModalsProvider.notifier)
                                  .openConcierge();
                              return;
                            }
                            if (id == NavTab.idCard) {
                              if (subscription?.effectiveTier.canUseVirtualCard !=
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
                                subscription?.effectiveTier.canViewEvents != true) {
                              showPaywall(context, featureName: 'Events');
                              return;
                            }
                            if (id == NavTab.legal &&
                                subscription?.effectiveTier.canViewEvents != true) {
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
          ChromeSummonZones(
            visible: showChrome,
            onSummon: () => ref.read(chromeVisibilityProvider.notifier).show(),
          ),
          const PushNotificationPrompt(enabled: false),
          GuidedTourOverlay(
            enabled: user != null,
            userId: user?.id,
            userCreatedAt: user?.createdAt,
          ),
        ],
      ),
    );
  }
}
