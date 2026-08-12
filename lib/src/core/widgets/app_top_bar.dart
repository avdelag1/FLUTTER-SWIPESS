import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            border: Border(
              bottom: BorderSide(color: Colors.white.withAlpha(18), width: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Left — back or logo
                if (showBack)
                  _GlassPill(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Icon(Icons.chevron_left_rounded, color: Colors.white.withAlpha(220), size: 22),
                  )
                else
                  _buildLogo(),

                const Spacer(),

                // Center title on inner screens
                if (showBack)
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.5)),

                const Spacer(),

                // Right actions
                Row(
                  children: [
                    if (showFilter && onFilterTap != null) ...[
                      _GlassPill(
                        onTap: onFilterTap,
                        child: Icon(Icons.tune_rounded, color: Colors.white.withAlpha(200), size: 18),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (showNotifications) ...[
                      _GlassPill(
                        badge: notificationCount,
                        onTap: onNotificationTap,
                        child: Icon(Icons.notifications_rounded, color: Colors.white.withAlpha(200), size: 18),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (showProfile)
                      _buildAvatar(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.swipe_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        const Text(
          'Swipess',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: onProfileTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
          ),
          border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
        ),
        child: avatarUrl != null
            ? ClipOval(child: Image.network(avatarUrl!, fit: BoxFit.cover))
            : const Icon(Icons.person_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final int badge;

  const _GlassPill({required this.child, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(18),
              border: Border.all(color: Colors.white.withAlpha(30), width: 1),
            ),
            child: Center(child: child),
          ),
          if (badge > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
