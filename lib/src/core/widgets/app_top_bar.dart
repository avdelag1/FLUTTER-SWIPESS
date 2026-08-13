import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
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
                onTap: onProfileTap ?? () {},
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(40),
                        image: avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl == null
                          ? const Icon(Icons.person_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    if (firstName != null && firstName!.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          firstName!,
                          style: const TextStyle(
                            color: Colors.white,
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(navTabProvider.notifier).set(NavTab.add);
                },
                child: const _WashIcon(
                  wash: Color(0xFF69DB7C),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 16, color: Color(0xFF69DB7C)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _GlassPill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  showGlassModal(
                    context: context,
                    builder: (_) => const TokensModal(),
                  );
                },
                child: const _WashIcon(
                  wash: Color(0xFFFFD43B),
                  badge: true,
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 16, color: Color(0xFFFFD43B)),
                ),
              ),
              const SizedBox(width: 8),
              _GlassPill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppPaths.map);
                },
                child: const _WashIcon(
                  wash: Color(0xFF4DABF7),
                  child: Icon(Icons.public_rounded,
                      size: 16, color: Color(0xFF4DABF7)),
                ),
              ),
              const SizedBox(width: 8),
              _GlassPill(
                onTap: () => HapticFeedback.lightImpact(),
                child: const _WashIcon(
                  wash: Color(0xFF9775FA),
                  child: Icon(Icons.dark_mode_rounded,
                      size: 16, color: Color(0xFF9775FA)),
                ),
              ),
              const SizedBox(width: 8),
              _GlassPill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppPaths.notifications);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const _WashIcon(
                      wash: Color(0xFFFF6B6B),
                      child: Icon(Icons.notifications_rounded,
                          size: 16, color: Color(0xFFFF6B6B)),
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
  });

  final Widget child;
  final VoidCallback onTap;
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
          color: Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withAlpha(55), width: 1.2),
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
            color: wash.withAlpha(45),
            shape: BoxShape.circle,
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
