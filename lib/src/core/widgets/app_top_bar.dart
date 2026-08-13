import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cap `TopBar` — profile + sparkles left; Crown / Globe / Moon / Bell right.
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
    final pillFill = Colors.transparent;
    final pillBorder = isLight ? Colors.black : Colors.white;

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
              _GlassPill(
                wide: true,
                fill: pillFill,
                border: pillBorder,
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
              _GlassPill(
                fill: pillFill,
                border: pillBorder,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showCreateListingChooser(context);
                },
                child: _WashIcon(
                  wash: const Color(0xFF82D2AF),
                  child: Icon(Icons.auto_awesome_rounded, size: 18, color: ink),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _GlassPill(
                fill: pillFill,
                border: pillBorder,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showGlassModal(
                    context: context,
                    builder: (_) => const TokensModal(),
                  );
                },
                child: _WashIcon(
                  wash: const Color(0xFFF5D25A),
                  badge: true,
                  child: Icon(Icons.workspace_premium_rounded, size: 18, color: ink),
                ),
              ),
              const SizedBox(width: 8),
              _GlassPill(
                fill: pillFill,
                border: pillBorder,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppPaths.map);
                },
                child: _WashIcon(
                  wash: const Color(0xFF78AFEB),
                  child: Icon(Icons.public_rounded, size: 18, color: ink),
                ),
              ),
              const SizedBox(width: 8),
              _GlassPill(
                fill: pillFill,
                border: pillBorder,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(visualThemeProvider.notifier).toggle();
                },
                child: _WashIcon(
                  wash: const Color(0xFF9775FA),
                  child: Icon(
                    isLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 18,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GlassPill(
                fill: pillFill,
                border: pillBorder,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppPaths.notifications);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _WashIcon(
                      wash: const Color(0xFFFF8C78),
                      child: Icon(Icons.notifications_rounded, size: 18, color: ink),
                    ),
                    ref.watch(unreadNotificationsProvider).when(
                          data: (count) {
                            if (count <= 0) {
                              return Positioned(
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
                              );
                            }
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

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.child,
    required this.onTap,
    this.wide = false,
    this.fill,
    this.border,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool wide;
  final Color? fill;
  final Color? border;

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
          color: fill ?? Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: border ?? Colors.white,
            width: 1.2,
          ),
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
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: wash.a == 0
                ? null
                : RadialGradient(
                    colors: [
                      wash.withAlpha(140),
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
