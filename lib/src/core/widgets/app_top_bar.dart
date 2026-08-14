import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// Bright neo-naïve washes — coral / sky / lemon / mint.
  static const coralWash = Color(0xFFFF8A7A);
  static const skyWash = Color(0xFF6BB8FF);
  static const lemonWash = Color(0xFFFFE066);
  static const mintWash = Color(0xFF7DFFAA);

  void _openProfile(BuildContext context) {
    HapticFeedback.lightImpact();
    if (onProfileTap != null) {
      onProfileTap!();
      return;
    }
    GoRouter.maybeOf(context)?.go(AppPaths.clientProfile);
  }

  Color _glyph(Color wash, Color ink) => Color.lerp(wash, ink, 0.28)!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(isLightThemeProvider);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final tokens = ref.watch(tokenBalanceProvider);
    // Cap `getTopBarChrome` / glassSurface (web solid neo-naïve).
    final pillFill = isLight
        ? const Color(0xF5FFFFFF) // rgba(255,255,255,0.96)
        : const Color(0xF5101016); // rgba(16,16,22,0.96)
    final pillBorder =
        isLight ? const Color(0xFF141414) : Colors.white.withAlpha(230);
    final hardShadow = isLight
        ? const Color(0xFF141414)
        : Colors.white.withAlpha(90);
    final moonWash = isLight ? lemonWash : skyWash;

    return Material(
      type: MaterialType.transparency,
      child: Container(
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
                  key: const ValueKey('header-profile'),
                  wide: true,
                  fill: pillFill,
                  border: pillBorder,
                  hardShadow: hardShadow,
                  onTap: () => _openProfile(context),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B4A), Color(0xFFFF4D00)],
                          ),
                          image: avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: avatarUrl == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: _glyph(coralWash, ink),
                              )
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
                    wash: mintWash,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: _glyph(mintWash, ink),
                    ),
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
                  wide: tokens > 0,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showGlassModal(
                      context: context,
                      builder: (_) => const TokensModal(),
                    );
                  },
                  child: _WashIcon(
                    wash: lemonWash,
                    badge: tokens > 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                          color: _glyph(lemonWash, ink),
                        ),
                        if (tokens > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$tokens',
                            style: GoogleFonts.plusJakartaSans(
                              color: _glyph(lemonWash, ink),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
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
                    wash: skyWash,
                    child: Icon(
                      Icons.public_rounded,
                      size: 16,
                      color: _glyph(skyWash, ink),
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
                    ref.read(visualThemeProvider.notifier).toggle();
                  },
                  child: _WashIcon(
                    wash: moonWash,
                    child: Icon(
                      isLight
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 16,
                      color: _glyph(moonWash, ink),
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
                        wash: coralWash,
                        child: Icon(
                          Icons.notifications_rounded,
                          size: 16,
                          color: _glyph(coralWash, ink),
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
      ),
    );
  }
}

/// Cap neo-naïve header pill — 2px ink ring + hard offset shadow.
class _NeoPill extends StatelessWidget {
  const _NeoPill({
    super.key,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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

  /// Center glow alpha — bright enough to read on black glass pills.
  static const glowAlpha = 220;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  wash.withAlpha(glowAlpha),
                  wash.withAlpha(110),
                  wash.withAlpha(0),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
        ),
        child,
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
