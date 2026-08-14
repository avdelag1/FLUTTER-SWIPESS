import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dashboard HUD — thick nexus glass, not tiny ink-stamp chips.
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
  Size get preferredSize => const Size.fromHeight(72);

  static const coralWash = Color(0xFFFF8A7A);
  static const skyWash = Color(0xFF6BB8FF);
  static const lemonWash = Color(0xFFFFE066);
  static const mintWash = Color(0xFF7DFFAA);

  static const _hudSize = 48.0;

  void _openProfile(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (onProfileTap != null) {
      onProfileTap!();
      return;
    }
    GoRouter.maybeOf(context)?.go(AppPaths.clientProfile);
  }

  Color _glyph(Color wash, Color ink) => Color.lerp(wash, Colors.white, 0.18)!;

  String get _label {
    final raw = firstName?.trim() ?? '';
    if (raw.isEmpty) return 'You';
    var s = raw.contains('@') ? raw.split('@').first : raw.split(' ').first;
    if (s.contains('.')) s = s.split('.').first;
    if (s.length > 10) s = '${s.substring(0, 9)}…';
    return s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(isLightThemeProvider);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final tokens = ref.watch(tokenBalanceProvider);
    final pillFill = isLight
        ? const Color(0xF2FFFFFF)
        : const Color(0xE616161C);
    final pillBorder =
        isLight ? const Color(0x33141414) : Colors.white.withAlpha(38);
    final moonWash = isLight ? lemonWash : skyWash;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: preferredSize.height + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 12,
          right: 12,
        ),
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _HudButton(
                  key: const ValueKey('header-profile'),
                  wide: true,
                  fill: pillFill,
                  border: pillBorder,
                  gradientBorder: NexusTheme.warm,
                  semanticLabel: 'Open profile',
                  onTap: () => _openProfile(context),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: NexusTheme.warm,
                          image: avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: avatarUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 86),
                        child: Text(
                          _label,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _HudButton(
                  fill: pillFill,
                  border: pillBorder,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showCreateListingChooser(context);
                  },
                  child: _WashIcon(
                    wash: mintWash,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 22,
                      color: _glyph(mintWash, ink),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _HudButton(
                  fill: pillFill,
                  border: pillBorder,
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
                          size: 22,
                          color: _glyph(lemonWash, ink),
                        ),
                        if (tokens > 0) ...[
                          const SizedBox(width: 5),
                          Text(
                            '$tokens',
                            style: GoogleFonts.plusJakartaSans(
                              color: _glyph(lemonWash, ink),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _HudButton(
                  fill: pillFill,
                  border: pillBorder,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(overlayModalsProvider.notifier).openPassportMap();
                  },
                  child: _WashIcon(
                    wash: skyWash,
                    child: Icon(
                      Icons.public_rounded,
                      size: 22,
                      color: _glyph(skyWash, ink),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _HudButton(
                  fill: pillFill,
                  border: pillBorder,
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
                      size: 22,
                      color: _glyph(moonWash, ink),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _HudButton(
                  fill: pillFill,
                  border: pillBorder,
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
                          size: 22,
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
                                  width: 9,
                                  height: 9,
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

/// Thick nexus HUD control — 48px glass, hairline, soft glow.
class _HudButton extends StatelessWidget {
  const _HudButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.fill,
    required this.border,
    this.wide = false,
    this.gradientBorder,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color fill;
  final Color border;
  final bool wide;
  final Gradient? gradientBorder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      height: AppTopBar._hudSize,
      width: wide ? null : AppTopBar._hudSize,
      padding: wide ? const EdgeInsets.fromLTRB(8, 0, 14, 0) : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: gradientBorder == null
            ? Border.all(color: border, width: 1.25)
            : null,
        boxShadow: [
          BoxShadow(
            color: (gradientBorder != null
                    ? AppTheme.brandPrimary
                    : Colors.black)
                .withAlpha(gradientBorder != null ? 70 : 70),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    final framed = gradientBorder == null
        ? inner
        : Container(
            padding: const EdgeInsets.all(1.6),
            decoration: BoxDecoration(
              gradient: gradientBorder,
              borderRadius: BorderRadius.circular(999),
            ),
            child: inner,
          );

    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: framed,
          ),
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

  static const glowAlpha = 220;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            width: 30,
            height: 30,
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
              width: 8,
              height: 8,
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
