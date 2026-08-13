import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';

/// Cap `TopBar` — neo-naïve glass pills + colored icon washes.
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isDashboard;
  final String? avatarUrl;
  final String? firstName;
  final VoidCallback? onProfileTap;

  const AppTopBar({
    super.key,
    this.isDashboard = true,
    this.avatarUrl,
    this.firstName,
    this.onProfileTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(isLightThemeProvider);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    // Cap `getTopBarChrome` / glassSurface (web solid neo-naïve).
    final pillFill = isLight
        ? const Color(0xF5FFFFFF) // rgba(255,255,255,0.96)
        : const Color(0xF5101016); // rgba(16,16,22,0.96)
    final pillBorder =
        isLight ? const Color(0xFF141414) : Colors.white.withAlpha(230);
    final hardShadow = isLight
        ? const Color(0xFF141414)
        : Colors.white.withAlpha(90);

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
      ),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _NeoPill(
                wide: true,
                fill: pillFill,
                border: pillBorder,
                hardShadow: hardShadow,
                onTap: onProfileTap ?? () {},
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ink.withAlpha(40),
                        image: avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl == null
                          ? Icon(Icons.person_rounded, size: 14, color: ink)
                          : null,
                    ),
                    if (firstName != null && firstName!.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          firstName!,
                          style: TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NeoPill(
                fill: pillFill,
                border: pillBorder,
                hardShadow: hardShadow,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showCreateListingChooser(context);
                },
                child: _WashIcon(
                  wash: const Color(0xFF69DB7C),
                  child: Icon(Icons.auto_awesome_rounded, size: 16, color: ink),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _NeoPill(
                fill: pillFill,
                border: pillBorder,
                hardShadow: hardShadow,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showGlassModal(
                    context: context,
                    builder: (_) => const TokensModal(),
                  );
                },
                child: _WashIcon(
                  wash: const Color(0xFFFFD43B),
                  badge: true,
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 16,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _NeoPill(
                fill: pillFill,
                border: pillBorder,
                hardShadow: hardShadow,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(overlayModalsProvider.notifier).openPassportMap();
                },
                child: _WashIcon(
                  wash: const Color(0xFF4DABF7),
                  child: Icon(Icons.public_rounded, size: 16, color: ink),
                ),
              ),
              const SizedBox(width: 8),
              _NeoPill(
                fill: pillFill,
                border: pillBorder,
                hardShadow: hardShadow,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(visualThemeProvider.notifier).toggle();
                },
                child: _WashIcon(
                  wash: isLight
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF4DABF7),
                  child: Icon(
                    isLight
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 16,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _NeoPill(
                fill: pillFill,
                border: pillBorder,
                hardShadow: hardShadow,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showGlassModal(
                    context: context,
                    builder: (_) => const NotificationsScreen(),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _WashIcon(
                      wash: const Color(0xFFFF6B6B),
                      child: Icon(
                        Icons.notifications_rounded,
                        size: 16,
                        color: ink,
                      ),
                    ),
                    ref.watch(unreadNotificationsProvider).when(
                          data: (count) {
                            if (count <= 0) return const SizedBox.shrink();
                            return Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.brandPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cap neo-naïve header pill — 2px ink ring + hard offset shadow.
class _NeoPill extends StatelessWidget {
  const _NeoPill({
    required this.child,
    required this.onTap,
    required this.fill,
    required this.border,
    required this.hardShadow,
    this.wide = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color fill;
  final Color border;
  final Color hardShadow;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        width: wide ? null : 36,
        padding: wide ? const EdgeInsets.symmetric(horizontal: 10) : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 2),
          boxShadow: [
            BoxShadow(
              color: hardShadow,
              offset: const Offset(1.25, 1.25),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _WashIcon extends StatelessWidget {
  const _WashIcon({
    required this.child,
    required this.wash,
    this.badge = false,
  });

  final Widget child;
  final Color wash;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                wash.withAlpha(110),
                wash.withAlpha(0),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
        if (badge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppTheme.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
