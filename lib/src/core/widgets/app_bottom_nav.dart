import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';

// Re-export so any old imports still work
export 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart' show NavTab;

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
                    ),
                    _DockIcon(
                      icon: Icons.local_fire_department_rounded,
                      active: activeTab == NavTab.likes,
                      onTap: () => onTabSelected(NavTab.likes),
                    ),
                    _DockIcon(
                      icon: Icons.smart_toy_rounded,
                      active: activeTab == NavTab.ai,
                      onTap: () => onTabSelected(NavTab.ai),
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
                    ),
                    _DockIcon(
                      icon: Icons.badge_rounded,
                      active: activeTab == NavTab.idCard,
                      onTap: () => onTabSelected(NavTab.idCard),
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
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int badge;
  final bool emphasized;

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
                    ? AppTheme.brandPrimary.withValues(alpha: 0.2)
                    : active
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.transparent,
              ),
              child: Icon(
                icon,
                size: 20,
                color: emphasized
                    ? const Color(0xFFFF4D6A)
                    : active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.82),
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
