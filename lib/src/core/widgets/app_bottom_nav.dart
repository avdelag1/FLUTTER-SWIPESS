import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_controls.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';

export 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart'
    show NavTab;

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    this.unreadMessages = 0,
  });

  final NavTab activeTab;
  final int unreadMessages;
  final ValueChanged<NavTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width < 360 ? 12.0 : width < 700 ? 20.0 : 28.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, 0, side, 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: DecoratedBox(
              decoration: AppTheme.bottomDockDecoration,
              child: SizedBox(
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    children: [
                      _item(
                        context,
                        tooltip: 'Home',
                        icon: activeTab == NavTab.dashboard
                            ? Icons.dashboard_rounded
                            : Icons.dashboard_outlined,
                        active: activeTab == NavTab.dashboard,
                        onTap: () => onTabSelected(NavTab.dashboard),
                        accent: SwipessTokens.brandOrange,
                      ),
                      _item(
                        context,
                        tooltip: 'Likes',
                        icon: activeTab == NavTab.likes
                            ? Icons.local_fire_department_rounded
                            : Icons.local_fire_department_outlined,
                        active: activeTab == NavTab.likes,
                        onTap: () => onTabSelected(NavTab.likes),
                        accent: SwipessTokens.brandPink,
                      ),
                      _item(
                        context,
                        tooltip: 'AI',
                        icon: Icons.auto_awesome_rounded,
                        active: activeTab == NavTab.ai,
                        onTap: () => onTabSelected(NavTab.ai),
                        accent: SwipessTokens.brandViolet,
                      ),
                      _item(
                        context,
                        tooltip: 'Create',
                        icon: Icons.add_rounded,
                        active: activeTab == NavTab.add,
                        emphasized: true,
                        onTap: () => onTabSelected(NavTab.add),
                        accent: AppTheme.brandPrimary,
                      ),
                      _item(
                        context,
                        tooltip: 'Messages',
                        icon: activeTab == NavTab.messages
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        active: activeTab == NavTab.messages,
                        badge: unreadMessages,
                        onTap: () => onTabSelected(NavTab.messages),
                        accent: SwipessTokens.brandBlue,
                      ),
                      _item(
                        context,
                        tooltip: 'Profile',
                        icon: activeTab == NavTab.idCard
                            ? Icons.account_circle_rounded
                            : Icons.account_circle_outlined,
                        active: activeTab == NavTab.idCard,
                        onTap: () => onTabSelected(NavTab.idCard),
                        accent: SwipessTokens.brandPink,
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

  Widget _item(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required Color accent,
    int badge = 0,
    bool emphasized = false,
  }) {
    return Expanded(
      child: Center(
        child: _DockIcon(
          tooltip: tooltip,
          icon: icon,
          active: active,
          onTap: onTap,
          badge: badge,
          emphasized: emphasized,
          accent: accent,
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.accent,
    this.badge = 0,
    this.emphasized = false,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int badge;
  final bool emphasized;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final badgeText = badge > 99 ? '99+' : '$badge';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: active,
        label: tooltip,
        child: SwipessPressable(
          onTap: onTap,
          haptic: SwipessHaptic.selection,
          borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: SwipessTokens.motionNormal,
                  curve: Curves.easeOutCubic,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: emphasized
                        ? accent
                        : active
                        ? accent.withAlpha(MatteSurface.isLight(context) ? 22 : 34)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    icon,
                    size: SwipessTokens.iconSize,
                    color: emphasized
                        ? Colors.white
                        : active
                        ? accent
                        : ink.withAlpha(205),
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: 1,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: SwipessTokens.brandPink,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(70),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        textAlign: TextAlign.center,
                        style: SwipessTokens.meta(
                          color: Colors.white,
                          fontSize: 8.5,
                        ).copyWith(fontWeight: FontWeight.w900, height: 1.1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
