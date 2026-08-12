import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

enum NavTab { swipe, events, add, messages, profile }

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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withAlpha(30), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(76),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(icon: Icons.local_fire_department_rounded, label: 'Discover', tab: NavTab.swipe, activeTab: activeTab, onTap: onTabSelected),
                  _NavItem(icon: Icons.celebration_rounded, label: 'Events', tab: NavTab.events, activeTab: activeTab, onTap: onTabSelected),
                  _AddButton(onTap: () { HapticFeedback.mediumImpact(); onTabSelected(NavTab.add); }),
                  _NavItem(icon: Icons.chat_bubble_rounded, label: 'Messages', tab: NavTab.messages, activeTab: activeTab, onTap: onTabSelected, badge: unreadMessages),
                  _NavItem(icon: Icons.person_rounded, label: 'Profile', tab: NavTab.profile, activeTab: activeTab, onTap: onTabSelected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final NavTab tab;
  final NavTab activeTab;
  final ValueChanged<NavTab> onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.tab,
    required this.activeTab,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tab == activeTab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(tab);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isActive
                          ? AppTheme.brandPrimary.withAlpha(40)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: isActive
                          ? AppTheme.brandPrimary
                          : Colors.white.withAlpha(127),
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AppTheme.brandPrimary : Colors.white.withAlpha(102),
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandPrimary.withAlpha(102),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
