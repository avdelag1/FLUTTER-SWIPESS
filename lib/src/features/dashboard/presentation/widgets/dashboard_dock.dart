import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/motion/ios_motion.dart';
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
                if (isLight)
                  BoxShadow(
                    color: Colors.white.withAlpha(80),
                    blurRadius: 5,
                    offset: const Offset(-1, -1),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 52,
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                decoration: BoxDecoration(
                  // Frozen glass without a live backdrop blur. Dark mode keeps
                  // the depth but intentionally has no white perimeter frame.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLight
                        ? const [
                            Color(0xFAFFFFFF),
                            Color(0xE7E1E8F0),
                            Color(0xF7F9FBFF),
                          ]
                        : const [
                            Color(0xF24A515B),
                            Color(0xEB252B33),
                            Color(0xF0353C46),
                          ],
                    stops: const [0, .55, 1],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isLight
                        ? Colors.white.withAlpha(245)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Stack(
                    children: [
                      if (selectedTab != null &&
                          items.indexWhere((i) => i.id == selectedTab) >= 0)
                        AnimatedPositioned(
                          duration: IosMotion.fast,
                          curve: IosMotion.enter,
                          left:
                              items.indexWhere((i) => i.id == selectedTab) *
                              44.0,
                          bottom: 0,
                          width: 44.0,
                          height: 44.0,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 2),
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
                          ),
                        ),
                      Row(
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
        NavTab.ai => 'SWIPESS AI',
        NavTab.add => 'Add listing',
        NavTab.messages => 'Messages',
        NavTab.idCard => 'Virtual ID card',
        NavTab.seekers => 'Requests',
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
                  scale: emphasized ? 1.08 : 1,
                  duration: IosMotion.fast,
                  curve: IosMotion.enter,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
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
    id: NavTab.events,
    icon: Icons.celebration_rounded,
    wash: Color(0xFFE95B9B),
    label: 'Events',
  ),
  BottomNavItem(
    id: NavTab.idCard,
    icon: Icons.shield_outlined,
    wash: Color(0xFF8B7CF6),
  ),
  BottomNavItem(
    id: NavTab.add,
    icon: Icons.auto_awesome_rounded,
    accent: true,
    wash: Color(0xFFFF5A52),
  ),
  BottomNavItem(id: NavTab.ai, useAiIcon: true, wash: Color(0xFF9B7BFF)),
  BottomNavItem(
    id: NavTab.likes,
    icon: Icons.local_fire_department_rounded,
    wash: Color(0xFFE64A8A),
  ),
  BottomNavItem(
    id: NavTab.messages,
    icon: Icons.chat_bubble_outline_rounded,
    wash: Color(0xFF5B9CF6),
  ),
  BottomNavItem(
    id: NavTab.legal,
    icon: Icons.balance_rounded,
    wash: Color(0xFF7E88E8),
    label: 'Lawyers',
  ),
  BottomNavItem(
    id: NavTab.seekers,
    icon: Icons.people_alt_rounded,
    wash: Color(0xFFD96FA8),
    label: 'Requests',
  ),
  BottomNavItem(
    id: NavTab.filter,
    icon: Icons.tune_rounded,
    wash: Color(0xFFE7A454),
  ),
];
