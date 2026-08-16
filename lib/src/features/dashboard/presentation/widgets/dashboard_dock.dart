import 'package:flutter/gestures.dart';
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

class DashboardDock extends StatefulWidget {
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
  State<DashboardDock> createState() => _DashboardDockState();
}

class _DashboardDockState extends State<DashboardDock> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(covariant DashboardDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revealSelected() {
    if (!mounted || !_controller.hasClients || widget.selectedTab == null) return;
    final index = widget.items.indexWhere((item) => item.id == widget.selectedTab);
    if (index < 0) return;

    const itemStride = 48.0;
    final viewport = _controller.position.viewportDimension;
    final target = (10 + index * itemStride - (viewport - 44) / 2)
        .clamp(0.0, _controller.position.maxScrollExtent)
        .toDouble();
    if ((_controller.offset - target).abs() < 2) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        container: true,
        label: 'Primary navigation',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xE6000000),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(58), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
                BoxShadow(color: Color(0x30FF4D6A), blurRadius: 22),
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
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, i) {
                  final item = widget.items[i];
                  return DockButton(
                    item: item,
                    wash: item.wash,
                    selected: widget.selectedTab == item.id,
                    onTap: () {
                      AppHaptics.light();
                      widget.onTabSelected(item.id);
                    },
                  );
                },
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

  String get _label => item.label ?? switch (item.id) {
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
    final iconColor = Colors.white.withAlpha(emphasized ? 255 : 242);

    return Semantics(
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
            radius: 24,
            splashColor: wash.withAlpha(90),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: AnimatedScale(
                  scale: emphasized ? 1 : 0.98,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        width: emphasized ? 36 : 34,
                        height: emphasized ? 36 : 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: emphasized
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    wash,
                                    Color.lerp(
                                          wash,
                                          const Color(0xFFEB4898),
                                          0.40,
                                        ) ??
                                        wash,
                                  ],
                                )
                              : RadialGradient(
                                  colors: [
                                    wash.withAlpha(165),
                                    wash.withAlpha(70),
                                  ],
                                ),
                          border: Border.all(
                            color: emphasized
                                ? Colors.white.withAlpha(105)
                                : wash.withAlpha(210),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: wash.withAlpha(emphasized ? 155 : 95),
                              blurRadius: emphasized ? 13 : 9,
                              spreadRadius: emphasized ? 1 : 0,
                            ),
                          ],
                        ),
                      ),
                      item.useAiIcon
                          ? CustomPaint(
                              painter: AiRobotPainter(color: iconColor),
                              size: const Size(20, 20),
                            )
                          : Icon(
                              item.icon,
                              size: item.accent ? 24 : 22,
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
    icon: Icons.home_rounded,
    wash: Color(0xFFFF4D00),
  ),
  BottomNavItem(
    id: NavTab.likes,
    icon: Icons.local_fire_department_rounded,
    wash: Color(0xFFE4007C),
  ),
  BottomNavItem(id: NavTab.ai, useAiIcon: true, wash: Color(0xFF9B6DFF)),
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
    wash: Color(0xFF8B5CF6),
  ),
  BottomNavItem(
    id: NavTab.seekers,
    icon: Icons.groups_rounded,
    wash: Color(0xFFFF4DA6),
  ),
  BottomNavItem(
    id: NavTab.filter,
    icon: Icons.tune_rounded,
    wash: Color(0xFFFF9F43),
  ),
  BottomNavItem(
    id: NavTab.legal,
    icon: Icons.balance_rounded,
    wash: Color(0xFF7C7CFF),
    label: 'Lawyers',
  ),
  BottomNavItem(
    id: NavTab.events,
    icon: Icons.event_rounded,
    wash: Color(0xFFFF2D8D),
    label: 'Events',
  ),
];
