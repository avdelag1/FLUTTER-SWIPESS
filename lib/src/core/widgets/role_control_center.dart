import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class RoleDashboardAction {
  const RoleDashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.path,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String path;
  final String? badge;
}

class RoleControlCenter extends StatelessWidget {
  const RoleControlCenter({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.statusLabel = 'Workspace active',
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<RoleDashboardAction> actions;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final secondary = isLight
        ? const Color(0xFF626A75)
        : Colors.white.withAlpha(166);

    return Scaffold(
      backgroundColor: AppTheme.canvasFor(isLight: isLight),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              sliver: SliverList.list(
                children: [
                  _GlassPanel(
                    isLight: isLight,
                    radius: 30,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _RoundIconButton(
                              icon: Icons.arrow_back_rounded,
                              isLight: isLight,
                              onTap: () {
                                if (Navigator.of(context).canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/client/dashboard');
                                }
                              },
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: AppTheme.dashboardFilterPill(
                                isLight: isLight,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF36D17C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: foreground,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          eyebrow.toUpperCase(),
                          style: TextStyle(
                            color: secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 32,
                            height: 1.02,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: secondary,
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'CONTROL CENTER',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 3 : 2;
                      final gap = 10.0;
                      final cardWidth =
                          (constraints.maxWidth - (gap * (columns - 1))) /
                          columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final action in actions)
                            SizedBox(
                              width: cardWidth,
                              child: _ActionCard(
                                action: action,
                                isLight: isLight,
                                onTap: () => context.go(action.path),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.isLight,
    required this.onTap,
  });

  final RoleDashboardAction action;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final secondary = isLight
        ? const Color(0xFF69717D)
        : Colors.white.withAlpha(156);

    return _GlassPanel(
      isLight: isLight,
      radius: 24,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 150),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: AppTheme.dashboardFilterPill(
                          isLight: isLight,
                        ),
                        alignment: Alignment.center,
                        child: Icon(action.icon, color: foreground, size: 20),
                      ),
                      const Spacer(),
                      if (action.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: AppTheme.dashboardFilterPill(
                            isLight: isLight,
                          ),
                          child: Text(
                            action.badge!,
                            style: TextStyle(
                              color: secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    action.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.isLight,
    required this.onTap,
  });

  final IconData icon;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: AppTheme.dashboardFilterPill(isLight: isLight),
          alignment: Alignment.center,
          child: Icon(icon, color: foreground, size: 20),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.isLight,
    required this.radius,
    required this.padding,
  });

  final Widget child;
  final bool isLight;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withAlpha(214)
                : AppTheme.dashGlassStrong.withAlpha(214),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isLight
                  ? Colors.black.withAlpha(22)
                  : Colors.white.withAlpha(38),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isLight ? 16 : 62),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
