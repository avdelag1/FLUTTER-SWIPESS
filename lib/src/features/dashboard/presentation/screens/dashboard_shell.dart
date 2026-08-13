import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/guided_tour_overlay.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/widgets/push_notification_prompt.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/widgets/seeker_request_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';
import 'package:go_router/go_router.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.child});

  final Widget child;

  static const _washes = [
    Color(0xFFFF6B6B), // coral
    Color(0xFF4DABF7), // sky
    Color(0xFFFFD43B), // lemon
    Color(0xFF69DB7C), // mint
    Color(0xFF9775FA), // violet
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
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

    final hideChrome = currentTab == NavTab.idCard;
    final isLight = ref.watch(isLightThemeProvider);
    final chromeVisible = ref.watch(chromeVisibilityProvider);
    final syncChrome = currentTab == NavTab.dashboard;
    final showChrome = !syncChrome || chromeVisible;
    final canvas = AppTheme.canvasFor(isLight: isLight);
    final dockFill = isLight ? Colors.white : Colors.black;
    final dockBorder = isLight ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: canvas,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: hideChrome
          ? null
          : PreferredSize(
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
          child,
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
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
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isLight ? 40 : 160),
                          blurRadius: 20,
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
                              selected: currentTab == bottomNavItems[i].id,
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
                                  showIntelCoreSheet(context);
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
    final ink = isLight ? Colors.black : Colors.white;
    final color = selected ? ink : ink.withAlpha(120);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: selected
                  ? Border.all(color: ink, width: 1.5)
                  : null,
            ),
            child: item.useAiIcon
                ? CustomPaint(
                    painter: _AiRobotPainter(color: color),
                    size: const Size(18, 18),
                  )
                : Icon(
                    item.icon,
                    size: 18,
                    color: color,
                  ),
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
