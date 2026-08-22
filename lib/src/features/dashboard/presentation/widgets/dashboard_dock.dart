import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';

class BottomNavItem {
  const BottomNavItem({
    required this.id,
    required this.wash,
    this.icon,
    this.accent = false,
    this.useAiIcon = false,
    this.label,
  });

  final NavTab id;
  final Color wash;
  final IconData? icon;
  final bool accent;
  final bool useAiIcon;
  final String? label;
}

class DashboardDock extends StatelessWidget {
  const DashboardDock({
    super.key,
    required this.items,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final List<BottomNavItem> items;
  final NavTab? selectedTab;
  final ValueChanged<NavTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Center(
      child: Semantics(
        container: true,
        label: 'Primary navigation',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 292),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 24 : 76),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.white.withAlpha(isLight ? 80 : 16),
                  blurRadius: 5,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.white.withAlpha(180)
                        : Colors.black.withAlpha(140),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white,
                      width: 2.0,
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Row(
                      children: [
                        for (final item in items)
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: DockButton(
                              item: item,
                              wash: item.wash,
                              selected: selectedTab == item.id,
                              onTap: () {
                                AppHaptics.light();
                                onTabSelected(item.id);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class DockButton extends StatelessWidget {
  const DockButton({
    super.key,
    required this.item,
    required this.wash,
    required this.selected,
    required this.onTap,
  });

  final BottomNavItem item;
  final Color wash;
  final bool selected;
  final VoidCallback onTap;

  String get _label =>
      item.label ??
      switch (item.id) {
        NavTab.dashboard => 'Home',
        NavTab.likes => 'Likes',
        NavTab.ai => 'Swipess AI',
        NavTab.add => 'Add listing',
        NavTab.messages => 'Messages',
        NavTab.idCard => 'Virtual ID card',
        NavTab.seekers => 'Seekers',
        NavTab.filter => 'Filters',
        NavTab.legal => 'Lawyers and legal services',
        NavTab.events => 'Events',
      };

  @override
  Widget build(BuildContext context) {
    final emphasized = selected || item.accent;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconColor = isLight
        ? Colors.black.withAlpha(emphasized ? 255 : 220)
        : Colors.white.withAlpha(emphasized ? 255 : 238);

    return SizedBox(
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        selected: selected,
        label: _label,
        child: Tooltip(
          message: _label,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: onTap,
              containedInkWell: true,
              highlightShape: BoxShape.circle,
              radius: 19,
              splashColor: wash.withAlpha(34),
              child: Center(
                child: AnimatedScale(
                  scale: emphasized ? 1.04 : 1,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (selected)
                        Positioned(
                          bottom: -2,
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: isLight
                                  ? Colors.black.withAlpha(205)
                                  : Colors.white.withAlpha(225),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      item.useAiIcon
                          ? CustomPaint(
                              painter: AiRobotPainter(color: iconColor),
                              size: const Size(18, 18),
                            )
                          : Icon(
                              item.icon ?? Icons.circle_outlined,
                              size: item.accent ? 23 : 21,
                              color: iconColor,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AiRobotPainter extends CustomPainter {
  AiRobotPainter({required this.color});
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
      Rect.fromLTWH(ox + s * .17, oy + s * .33, s * .66, s * .5),
      Radius.circular(s * .08),
    );
    canvas.drawRRect(r, p);
    canvas.drawLine(
      Offset(ox + s * .08, oy + s * .58),
      Offset(ox + s * .17, oy + s * .58),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * .83, oy + s * .58),
      Offset(ox + s * .92, oy + s * .58),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * .38, oy + s * .54),
      Offset(ox + s * .38, oy + s * .62),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * .62, oy + s * .54),
      Offset(ox + s * .62, oy + s * .62),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * .5, oy + s * .33),
      Offset(ox + s * .5, oy + s * .17),
      p,
    );
    canvas.drawLine(
      Offset(ox + s * .5, oy + s * .17),
      Offset(ox + s * .33, oy + s * .17),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant AiRobotPainter oldDelegate) =>
      oldDelegate.color != color;
}

const defaultDashboardNavItems = [
  BottomNavItem(
    id: NavTab.dashboard,
    icon: Icons.home_rounded,
    wash: Color(0xFFFF7A45),
  ),
  BottomNavItem(
    id: NavTab.likes,
    icon: Icons.local_fire_department_rounded,
    wash: Color(0xFFE64A8A),
  ),
  BottomNavItem(id: NavTab.ai, useAiIcon: true, wash: Color(0xFF9B7BFF)),
  BottomNavItem(
    id: NavTab.add,
    icon: Icons.add_rounded,
    accent: true,
    wash: Color(0xFFFF5A52),
  ),
  BottomNavItem(
    id: NavTab.messages,
    icon: Icons.chat_bubble_outline_rounded,
    wash: Color(0xFF5B9CF6),
  ),
  BottomNavItem(
    id: NavTab.idCard,
    icon: Icons.shield_outlined,
    wash: Color(0xFF8B7CF6),
  ),
  BottomNavItem(
    id: NavTab.seekers,
    icon: Icons.people_alt_rounded,
    wash: Color(0xFFD96FA8),
  ),
  BottomNavItem(
    id: NavTab.filter,
    icon: Icons.tune_rounded,
    wash: Color(0xFFE7A454),
  ),
  BottomNavItem(
    id: NavTab.legal,
    icon: Icons.balance_rounded,
    wash: Color(0xFF7E88E8),
    label: 'Lawyers',
  ),
  BottomNavItem(
    id: NavTab.events,
    icon: Icons.celebration_rounded,
    wash: Color(0xFFE95B9B),
    label: 'Events',
  ),
];