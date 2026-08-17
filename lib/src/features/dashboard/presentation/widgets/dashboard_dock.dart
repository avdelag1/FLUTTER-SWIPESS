import 'dart:ui';

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

    const itemStride = 44.0;
    final viewport = _controller.position.viewportDimension;
    final target = (8 + index * itemStride - (viewport - 40) / 2)
        .clamp(0.0, _controller.position.maxScrollExtent)
        .toDouble();
    if ((_controller.offset - target).abs() < 2) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Center(
      child: Semantics(
        container: true,
        label: 'Primary navigation',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 22 : 64),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.white.withAlpha(166)
                        : Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withAlpha(isLight ? 120 : 54),
                      width: .8,
                    ),
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: false,
                      overscroll: false,
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: ListView.separated(
                      controller: _controller,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      itemCount: widget.items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 2),
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
    // Keep every glyph bright and legible. Color is used as a restrained glow,
    // not as the glyph itself, so no nav action can disappear on dark glass.
    final iconColor = Colors.white.withAlpha(emphasized ? 255 : 238);

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
            radius: 22,
            splashColor: wash.withAlpha(52),
            child: SizedBox(
              width: 40,
              height: 48,
              child: Center(
                child: AnimatedScale(
                  scale: emphasized ? 1.06 : 1,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (selected)
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: wash,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: wash.withAlpha(150), blurRadius: 7),
                              ],
                            ),
                          ),
                        ),
                      item.useAiIcon
                          ? CustomPaint(
                              painter: AiRobotPainter(color: iconColor),
                              size: const Size(22, 22),
                            )
                          : Icon(
                              item.icon ?? Icons.circle_outlined,
                              size: item.accent ? 27 : 25,
                              color: iconColor,
                              shadows: [
                                Shadow(
                                  color: wash.withAlpha(emphasized ? 125 : 70),
                                  blurRadius: emphasized ? 8 : 5,
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
    canvas.drawLine(Offset(ox + s * 0.08, oy + s * 0.58), Offset(ox + s * 0.17, oy + s * 0.58), p);
    canvas.drawLine(Offset(ox + s * 0.83, oy + s * 0.58), Offset(ox + s * 0.92, oy + s * 0.58), p);
    canvas.drawLine(Offset(ox + s * 0.38, oy + s * 0.54), Offset(ox + s * 0.38, oy + s * 0.62), p);
    canvas.drawLine(Offset(ox + s * 0.62, oy + s * 0.54), Offset(ox + s * 0.62, oy + s * 0.62), p);
    canvas.drawLine(Offset(ox + s * 0.5, oy + s * 0.33), Offset(ox + s * 0.5, oy + s * 0.17), p);
    canvas.drawLine(Offset(ox + s * 0.5, oy + s * 0.17), Offset(ox + s * 0.33, oy + s * 0.17), p);
  }

  @override
  bool shouldRepaint(covariant AiRobotPainter oldDelegate) => oldDelegate.color != color;
}

const defaultDashboardNavItems = [
  BottomNavItem(id: NavTab.dashboard, icon: Icons.home_rounded, wash: Color(0xFFFF7A45)),
  BottomNavItem(id: NavTab.likes, icon: Icons.local_fire_department_rounded, wash: Color(0xFFE64A8A)),
  BottomNavItem(id: NavTab.ai, useAiIcon: true, wash: Color(0xFF9B7BFF)),
  // Use simple, widely-supported glyphs so these controls never render blank
  // in Flutter web/PWA builds.
  BottomNavItem(id: NavTab.add, icon: Icons.add_rounded, accent: true, wash: Color(0xFFFF5A52)),
  BottomNavItem(id: NavTab.messages, icon: Icons.chat_bubble_outline_rounded, wash: Color(0xFF5B9CF6)),
  BottomNavItem(id: NavTab.idCard, icon: Icons.shield_outlined, wash: Color(0xFF8B7CF6)),
  BottomNavItem(id: NavTab.seekers, icon: Icons.people_alt_rounded, wash: Color(0xFFD96FA8)),
  BottomNavItem(id: NavTab.filter, icon: Icons.tune_rounded, wash: Color(0xFFE7A454)),
  BottomNavItem(id: NavTab.legal, icon: Icons.balance_rounded, wash: Color(0xFF7E88E8), label: 'Lawyers'),
  BottomNavItem(id: NavTab.events, icon: Icons.celebration_rounded, wash: Color(0xFFE95B9B), label: 'Events'),
];
