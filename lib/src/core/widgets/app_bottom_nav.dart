import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';

// Re-export so any old imports still work
export 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart'
    show NavTab;

class AppBottomNav extends StatelessWidget {
  final NavTab activeTab;
  final int unreadMessages;
  final ValueChanged<NavTab> onTabSelected;

  const AppBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    this.unreadMessages = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: AppTheme.bottomDockDecoration,
              child: SizedBox(
                height: 58,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DockIcon(
                      icon: Icons.dashboard_rounded,
                      active: activeTab == NavTab.dashboard,
                      onTap: () => onTabSelected(NavTab.dashboard),
                      iconColor: const Color(0xFFFF4D00), // Vibrant Orange/Red
                    ),
                    _DockIcon(
                      icon: Icons.local_fire_department_rounded,
                      active: activeTab == NavTab.likes,
                      onTap: () => onTabSelected(NavTab.likes),
                      iconColor: const Color(0xFFFF007F), // Neon Pink
                    ),
                    _DockIcon(
                      icon: Icons.smart_toy_rounded, // AI/Events icon
                      active: activeTab == NavTab.ai,
                      onTap: () => onTabSelected(NavTab.ai),
                      iconColor: const Color(0xFF9D4EDD), // Bright Purple
                    ),
                    _DockIcon(
                      icon: Icons.add_rounded,
                      active: false,
                      emphasized: true,
                      onTap: () => onTabSelected(NavTab.add),
                    ),
                    _DockIcon(
                      icon: Icons.chat_bubble_rounded,
                      active: activeTab == NavTab.messages,
                      badge: unreadMessages,
                      onTap: () => onTabSelected(NavTab.messages),
                      iconColor: const Color(0xFF3B82F6), // Bright Blue
                    ),
                    _DockIcon(
                      icon: Icons.badge_rounded,
                      active: activeTab == NavTab.idCard,
                      onTap: () => onTabSelected(NavTab.idCard),
                      iconColor: const Color(0xFFE4007C), // Magenta
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge = 0,
    this.emphasized = false,
    this.iconColor,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int badge;
  final bool emphasized;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: emphasized
                    ? const Color(0xFFFF4D00) // Solid CTA red/orange
                    : active
                    ? (iconColor?.withValues(alpha: 0.2) ?? Colors.white.withValues(alpha: 0.12))
                    : Colors.transparent,
              ),
              child: Icon(
                icon,
                size: 20,
                color: emphasized
                    ? Colors.white
                    : active
                    ? (iconColor ?? Colors.white)
                    : (iconColor?.withValues(alpha: 0.8) ?? Colors.white.withValues(alpha: 0.82)),
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
