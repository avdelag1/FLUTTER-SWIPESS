import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool showProfile;
  final bool showNotifications;
  final int notificationCount;
  final String? avatarUrl;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onFilterTap;
  final bool showFilter;

  const AppTopBar({
    super.key,
    this.title = 'Swipess',
    this.showBack = false,
    this.showProfile = true,
    this.showNotifications = true,
    this.notificationCount = 0,
    this.avatarUrl,
    this.onProfileTap,
    this.onNotificationTap,
    this.onFilterTap,
    this.showFilter = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Row(
          children: [
            if (showBack)
              _ChromeIcon(
                icon: Icons.chevron_left_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SwipessLogo(height: 22, variant: SwipessLogoVariant.white),
              ),
            const Spacer(),
            if (showFilter && onFilterTap != null) ...[
              _ChromeIcon(icon: Icons.tune_rounded, onTap: onFilterTap!),
              const SizedBox(width: 8),
            ],
            _ChromeIcon(
              icon: Icons.workspace_premium_outlined,
              onTap: () => _toast(context, 'Passport'),
            ),
            const SizedBox(width: 8),
            if (showNotifications)
              _ChromeIcon(
                icon: Icons.notifications_none_rounded,
                onTap: onNotificationTap ?? () {},
                badge: notificationCount,
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onProfileTap,
              child: DecoratedBox(
                decoration: AppTheme.glassPill(),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: avatarUrl != null
                        ? ClipOval(
                            child: Image.network(avatarUrl!, width: 28, height: 28, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.person_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 1200)),
    );
  }
}

class _ChromeIcon extends StatelessWidget {
  const _ChromeIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: AppTheme.glassPill(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, color: Colors.white, size: 16),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -2,
              right: -2,
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
    );
  }
}
