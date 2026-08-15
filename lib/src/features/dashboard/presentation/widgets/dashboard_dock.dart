import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';

class BottomNavItem {
  const BottomNavItem({
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(36), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x26FF4D6A), blurRadius: 20),
            ],
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
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final item = items[i];
                return DockButton(
                  item: item,
                  wash: item.wash,
                  selected: selectedTab == item.id,
                  onTap: () {
                    AppHaptics.light();
                    onTabSelected(item.id);
                  },
                );
              },
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
                          colors: [wash.withAlpha(70), wash.withAlpha(0)],
                        ),
                  boxShadow: selected || item.accent
                      ? [BoxShadow(color: wash.withAlpha(120), blurRadius: 10)]
                      : null,
                ),
              ),
              item.useAiIcon
                  ? CustomPaint(
                      painter: AiRobotPainter(color: color),
                      size: const Size(18, 18),
                    )
                  : Icon(item.icon, size: item.accent ? 22 : 20, color: color),
            ],
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
  bool shouldRepaint(covariant AiRobotPainter oldDelegate) =>
      oldDelegate.color != color;
}

const defaultDashboardNavItems = [
  BottomNavItem(
    id: NavTab.dashboard,
    icon: Icons.dashboard_rounded,
    wash: Color(0xFFFF4D00),
  ),
  BottomNavItem(
    id: NavTab.likes,
    icon: Icons.local_fire_department_rounded,
    wash: Color(0xFFE4007C),
  ),
  BottomNavItem(id: NavTab.ai, useAiIcon: true, wash: Color(0xFF8B5CF6)),
  BottomNavItem(
    id: NavTab.add,
    icon: Icons.add_rounded,
    accent: true,
    wash: Color(0xFFFF4D00),
  ),
  BottomNavItem(
    id: NavTab.messages,
    icon: Icons.chat_bubble_rounded,
    wash: Color(0xFF3B82F6),
  ),
  BottomNavItem(
    id: NavTab.idCard,
    icon: Icons.badge_rounded,
    wash: Color(0xFF7C3AED),
  ),
  BottomNavItem(
    id: NavTab.seekers,
    icon: Icons.groups_rounded,
    wash: Color(0xFFEB4898),
  ),
  BottomNavItem(
    id: NavTab.filter,
    icon: Icons.tune_rounded,
    wash: Color(0xFFFF8C42),
  ),
  BottomNavItem(
    id: NavTab.legal,
    icon: Icons.gavel_rounded,
    wash: Color(0xFF6366F1),
  ),
  BottomNavItem(
    id: NavTab.events,
    icon: Icons.local_activity_rounded,
    wash: Color(0xFFE4007C),
  ),
];
