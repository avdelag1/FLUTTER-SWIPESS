import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/chrome_summon_zones.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/guided_tour_overlay.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/widgets/push_notification_prompt.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';
import 'package:go_router/go_router.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  bool _eventsMounted = false;
  String? _lastLocation;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (_lastLocation != location) {
      _lastLocation = location;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(chromeVisibilityProvider.notifier).show();
      });
    }
    final isDashboard = location == AppPaths.clientDashboard ||
        location == AppPaths.legacyDashboard;
    final isProfile = location == AppPaths.clientProfile;
    final isEvents = location == AppPaths.exploreEvents;
    if (isEvents) _eventsMounted = true;
    final routeTab = AppPaths.tabForLocation(location);
    final currentTab = routeTab ?? ref.watch(navTabProvider);
    final user = ref.watch(currentUserProvider);

    // Keep provider in sync for any legacy listeners.
    if (routeTab != null && ref.read(navTabProvider) != routeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(navTabProvider) != routeTab) {
          ref.read(navTabProvider.notifier).set(routeTab);
        }
      });
    }

    final profile = ref.watch(currentProfileProvider).value;

    // Cap BottomNavigation order (scrollable dock).
    final bottomNavItems = [
      _BottomNavItem(
        id: NavTab.dashboard,
        icon: Icons.dashboard_rounded,
        wash: const Color(0xFFFF4D00),
      ),
      _BottomNavItem(
        id: NavTab.likes,
        icon: Icons.favorite_rounded,
        wash: const Color(0xFFE4007C),
      ),
      _BottomNavItem(
        id: NavTab.ai,
        useAiIcon: true,
        wash: const Color(0xFF8B5CF6),
      ),
      _BottomNavItem(
        id: NavTab.add,
        icon: Icons.add_rounded,
        accent: true,
        wash: const Color(0xFFFF4D00),
      ),
      _BottomNavItem(
        id: NavTab.messages,
        icon: Icons.chat_bubble_rounded,
        wash: const Color(0xFF3B82F6),
      ),
      _BottomNavItem(
        id: NavTab.idCard,
        icon: Icons.badge_rounded,
        wash: const Color(0xFF7C3AED),
      ),
      _BottomNavItem(
        id: NavTab.seekers,
        icon: Icons.groups_rounded,
        wash: const Color(0xFFEB4898),
      ),
      _BottomNavItem(
        id: NavTab.filter,
        icon: Icons.tune_rounded,
        wash: const Color(0xFFFF8C42),
      ),
      _BottomNavItem(
        id: NavTab.legal,
        icon: Icons.gavel_rounded,
        wash: const Color(0xFF6366F1),
      ),
      _BottomNavItem(
        id: NavTab.events,
        icon: Icons.local_activity_rounded,
        wash: const Color(0xFFE4007C),
      ),
    ];

    final isLight = ref.watch(isLightThemeProvider);
    final chromeVisible = ref.watch(chromeVisibilityProvider);
    final showChrome = chromeVisible;
    final showHeader = showChrome && (isDashboard || isProfile);
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
              return false; // let the notification bubble up if needed
            },
            child: AnimatedPadding(
              duration: Duration(milliseconds: showChrome ? 360 : 340),
              curve: const Cubic(0.25, 0.1, 0.25, 1),
              padding: EdgeInsets.only(
                top: showHeader ? 96 : 0, // AppTopBar height + safe area approx
                bottom: showChrome ? 88 : 0, // Dock height + safe area approx
              ),
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
                        child: const EventsScreen(),
                      ),
                    ),
                  if (!isDashboard && !isEvents) widget.child,
                ],
              ),
            ),
          ),
          // Overlay (not Scaffold.appBar) so nested page Scaffolds cannot
          // steal taps from the HUD — Cap `TopBar` is `fixed` + z-index 100.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: showHeader ? 1 : 0,
              duration: Duration(milliseconds: showChrome ? 360 : 340),
              curve: const Cubic(0.25, 0.1, 0.25, 1),
              child: AnimatedSlide(
                offset: showHeader ? Offset.zero : const Offset(0, -0.12),
                duration: Duration(milliseconds: showChrome ? 360 : 340),
                curve: const Cubic(0.25, 0.1, 0.25, 1),
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
              duration: Duration(milliseconds: showChrome ? 360 : 340),
              curve: const Cubic(0.25, 0.1, 0.25, 1),
              child: AnimatedSlide(
                offset: showChrome ? Offset.zero : const Offset(0, 1.0),
                duration: Duration(milliseconds: showChrome ? 360 : 340),
                curve: const Cubic(0.25, 0.1, 0.25, 1),
                child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withAlpha(36),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false,
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: bottomNavItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 4),
                        itemBuilder: (context, i) {
                          final item = bottomNavItems[i];
                          return _DockButton(
                            item: item,
                            wash: item.wash,
                            selected: dockSelected == item.id,
                            isLight: isLight,
                            onTap: () {
                              AppHaptics.light();
                              final id = item.id;
                              if (id == NavTab.filter) {
                                FilterBottomSheet.show(context);
                                return;
                              }
                              if (id == NavTab.add) {
                                context.push(AppPaths.ownerProperties);
                                return;
                              }
                              if (id == NavTab.ai) {
                                if (overlays.showConcierge) {
                                  ref
                                      .read(chromeVisibilityProvider
                                          .notifier)
                                          .hide();
                                  return;
                                }
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .openConcierge();
                                return;
                              }
                              if (id == NavTab.idCard) {
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .openVapId();
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
          ),
          ),
          ),
          ),
          ChromeSummonZones(
            visible: showChrome,
            onSummon: () =>
                ref.read(chromeVisibilityProvider.notifier).show(),
          ),
          // Hidden until remote push is wired. Showing a prompt that
          // then says "not wired" is an App Store 2.1 reject.
          const PushNotificationPrompt(enabled: false),
          GuidedTourOverlay(enabled: user != null),
        ],
      ),
    );
  }
}

class _BottomNavItem {
  _BottomNavItem({
    required this.id,
    required this.wash,
    this.icon,
    this.accent = false,
    this.useAiIcon = false,
  });

  final NavTab id;
  final Color wash;
  final IconData? icon;
  final bool accent;
  final bool useAiIcon;
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.wash,
    required this.selected,
    required this.onTap,
    this.isLight = false,
  });

  final _BottomNavItem item;
  final Color wash;
  final bool selected;
  final VoidCallback onTap;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final color = selected || item.accent ? Colors.white : wash;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: selected || item.accent ? 34 : 30,
                height: selected || item.accent ? 34 : 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected || item.accent
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            wash,
                            Color.lerp(wash, const Color(0xFFEB4898), 0.55) ??
                                wash,
                          ],
                        )
                      : RadialGradient(
                          colors: [
                            wash.withAlpha(70),
                            wash.withAlpha(0),
                          ],
                        ),
                  boxShadow: selected || item.accent
                      ? [
                          BoxShadow(
                            color: wash.withAlpha(120),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
              item.useAiIcon
                  ? CustomPaint(
                      painter: _AiRobotPainter(color: color),
                      size: const Size(18, 18),
                    )
                  : Icon(
                      item.icon,
                      size: item.accent ? 22 : 20,
                      color: color,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cap `AIIcon` — robot head for Intel Core dock button.
class _AiRobotPainter extends CustomPainter {
  _AiRobotPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.shortestSide;
    final ox = (size.width - s) / 2;
    final oy = (size.height - s) / 2;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(ox + s * 0.17, oy + s * 0.33, s * 0.66, s * 0.5),
      Radius.circular(s * 0.08),
    );
    canvas.drawRRect(r, p);
    canvas.drawLine(
      Offset(ox + s * 0.08, oy + s * 0.58),
      Offset(ox + s * 0.17, oy + s * 0.58),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * 0.83, oy + s * 0.58),
      Offset(ox + s * 0.92, oy + s * 0.58),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * 0.38, oy + s * 0.54),
      Offset(ox + s * 0.38, oy + s * 0.62),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * 0.62, oy + s * 0.54),
      Offset(ox + s * 0.62, oy + s * 0.62),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * 0.5, oy + s * 0.33),
      Offset(ox + s * 0.5, oy + s * 0.17),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * 0.5, oy + s * 0.17),
      Offset(ox + s * 0.33, oy + s * 0.17),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _AiRobotPainter oldDelegate) =>
      oldDelegate.color != color;
}
