import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/guided_tour_overlay.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/widgets/push_notification_prompt.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/widgets/seeker_request_sheet.dart';
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

  static const _washes = [
    Color(0xFFFF6B6B), // coral
    Color(0xFF4DABF7), // sky
    Color(0xFFFFD43B), // lemon
    Color(0xFF69DB7C), // mint
    Color(0xFF9775FA), // violet
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isDashboard = location == AppPaths.clientDashboard ||
        location == AppPaths.legacyDashboard;
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
      _BottomNavItem(id: NavTab.dashboard, icon: Icons.bolt_rounded),
      _BottomNavItem(
          id: NavTab.likes, icon: Icons.local_fire_department_rounded),
      _BottomNavItem(id: NavTab.ai, useAiIcon: true),
      _BottomNavItem(
        id: NavTab.add,
        icon: Icons.add_circle_rounded,
        accent: true,
      ),
      _BottomNavItem(id: NavTab.messages, icon: Icons.chat_bubble_outline_rounded),
      _BottomNavItem(id: NavTab.idCard, icon: Icons.verified_user_outlined),
      _BottomNavItem(id: NavTab.seekers, icon: Icons.people_outline_rounded),
      _BottomNavItem(id: NavTab.filter, icon: Icons.tune_rounded),
      _BottomNavItem(id: NavTab.legal, icon: Icons.balance_rounded),
      _BottomNavItem(id: NavTab.events, icon: Icons.celebration_rounded),
    ];

    final isLight = ref.watch(isLightThemeProvider);
    final chromeVisible = ref.watch(chromeVisibilityProvider);
    final showChrome = chromeVisible;
    final overlays = ref.watch(overlayModalsProvider);
    final dockSelected = overlays.showVapId
        ? NavTab.idCard
        : overlays.showConcierge
            ? NavTab.ai
            : currentTab;
    final canvas = AppTheme.canvasFor(isLight: isLight);
    // Cap `getBottomNavChrome` — neo-naïve glass + hard ink ring.
    final dockFill = isLight
        ? const Color(0xF5FFFFFF)
        : const Color(0xF5101016);
    final dockBorder =
        isLight ? const Color(0xFF141414) : Colors.white.withAlpha(230);
    final dockHardShadow =
        isLight ? const Color(0xFF141414) : Colors.white.withAlpha(90);

    return Scaffold(
      backgroundColor: canvas,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: PreferredSize(
              preferredSize: const AppTopBar().preferredSize,
              child: AnimatedOpacity(
                opacity: showChrome ? 1 : 0,
                duration: Duration(milliseconds: showChrome ? 360 : 340),
                curve: const Cubic(0.25, 0.1, 0.25, 1),
                child: AnimatedSlide(
                  offset: showChrome ? Offset.zero : const Offset(0, -0.12),
                  duration: Duration(milliseconds: showChrome ? 360 : 340),
                  curve: const Cubic(0.25, 0.1, 0.25, 1),
                  child: IgnorePointer(
                    ignoring: !showChrome,
                    child: AppTopBar(
                      firstName: profile?.name.split(' ').first,
                      avatarUrl: profile?.avatarUrl,
                      onProfileTap: () => context.push(AppPaths.clientProfile),
                    ),
                  ),
                ),
              ),
            ),
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
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: showChrome ? 1 : 0,
              duration: Duration(milliseconds: showChrome ? 360 : 340),
              curve: const Cubic(0.25, 0.1, 0.25, 1),
              child: AnimatedSlide(
                offset: showChrome ? Offset.zero : const Offset(0, 0.5),
                duration: Duration(milliseconds: showChrome ? 360 : 340),
                curve: const Cubic(0.25, 0.1, 0.25, 1),
                child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: dockFill,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: dockBorder,
                        width: 2.25,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: dockHardShadow,
                          offset: const Offset(1.5, 1.5),
                          blurRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withAlpha(isLight ? 40 : 160),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var i = 0; i < bottomNavItems.length; i++)
                            _DockButton(
                              item: bottomNavItems[i],
                              wash: _washes[i % _washes.length],
                              selected: dockSelected == bottomNavItems[i].id,
                              isLight: isLight,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final id = bottomNavItems[i].id;
                                if (id == NavTab.filter) {
                                  FilterBottomSheet.show(context);
                                  return;
                                }
                                if (id == NavTab.add) {
                                  showCreateListingChooser(context);
                                  return;
                                }
                                if (id == NavTab.ai) {
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
                                // Cap SEEKERS dock opens SeekerRequestDialog.
                                if (id == NavTab.seekers) {
                                  showSeekerRequestSheet(context, ref);
                                  return;
                                }
                                ref.read(navTabProvider.notifier).set(id);
                                context.go(AppPaths.pathForTab(id));
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ),
          ),
          PushNotificationPrompt(enabled: user != null),
          GuidedTourOverlay(enabled: user != null),
        ],
      ),
    );
  }
}

class _BottomNavItem {
  _BottomNavItem({
    required this.id,
    this.icon,
    this.accent = false,
    this.useAiIcon = false,
  });

  final NavTab id;
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
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    // Cap: active = full ink; inactive muted. No circular glass discs.
    final color = item.accent
        ? const Color(0xFFFF4D6A)
        : (selected ? ink : ink.withAlpha(isLight ? 140 : 170));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cap neo-naive nav wash (coral/sky/lemon/mint/violet).
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      wash.withAlpha(selected || item.accent ? 90 : 45),
                      wash.withAlpha(0),
                    ],
                  ),
                ),
              ),
              if (item.accent)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF4D6A),
                      width: 1.5,
                    ),
                  ),
                ),
              item.useAiIcon
                  ? CustomPaint(
                      painter: _AiRobotPainter(color: color),
                      size: const Size(18, 18),
                    )
                  : Icon(
                      item.icon,
                      size: item.accent ? 22 : 18,
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
      ..strokeWidth = 1.7
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
