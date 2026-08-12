import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class DashboardNavItem {
  const DashboardNavItem({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}

const dashboardNavItems = [
  DashboardNavItem(id: 'dashboard', icon: Icons.bolt_rounded, label: 'Dashboard'),
  DashboardNavItem(id: 'likes', icon: Icons.local_fire_department_outlined, label: 'Likes'),
  DashboardNavItem(id: 'ai', icon: Icons.auto_awesome, label: 'AI Bot'),
  DashboardNavItem(id: 'add', icon: Icons.add_circle_outline, label: 'Add'),
  DashboardNavItem(id: 'messages', icon: Icons.chat_bubble_outline, label: 'Messages'),
  DashboardNavItem(id: 'vapid', icon: Icons.verified_user_outlined, label: 'ID Card'),
  DashboardNavItem(id: 'seekers', icon: Icons.groups_outlined, label: 'Seekers'),
  DashboardNavItem(id: 'search', icon: Icons.tune, label: 'Filter'),
  DashboardNavItem(id: 'legal', icon: Icons.balance, label: 'Legal'),
  DashboardNavItem(id: 'events', icon: Icons.celebration_outlined, label: 'Events'),
];

class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.activeId,
    required this.onSelected,
  });

  final String activeId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: DecoratedBox(
              decoration: AppTheme.bottomDockDecoration,
              child: SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: dashboardNavItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final item = dashboardNavItems[index];
                    final active = item.id == activeId;
                    final isAdd = item.id == 'add';
                    return IconButton(
                      tooltip: item.label,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onSelected(item.id);
                      },
                      icon: Icon(
                        item.icon,
                        size: isAdd ? 24 : 20,
                        color: isAdd
                            ? const Color(0xFFFF4D6A)
                            : active
                                ? Colors.white
                                : const Color(0xEBFFFFFF),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
