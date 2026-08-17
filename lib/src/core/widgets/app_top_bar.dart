import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dashboard HUD using the same liquid-glass language as the bottom dock.
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

  static const addWash = Color(0xFFFF4D00);
  static const mapWash = Color(0xFF3B82F6);
  static const themeWash = Color(0xFF8B5CF6);
  static const bellWash = Color(0xFFE4007C);
  static const tokenWash = Color(0xFFFFB300);

  static const _hudSize = 44.0;

  void _openProfile(BuildContext context) {
    AppHaptics.medium();
    if (onProfileTap != null) {
      onProfileTap!();
      return;
    }
    GoRouter.maybeOf(context)?.go(AppPaths.clientProfile);
  }

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
    final chromeGap = MediaQuery.sizeOf(context).width < 360 ? 4.0 : 8.0;

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
                _ProfileAvatarButton(
                  key: const ValueKey('header-profile'),
                  avatarUrl: avatarUrl,
                  ink: ink,
                  isLight: isLight,
                  semanticLabel: 'Open profile, $_label',
                  onTap: () => _openProfile(context),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-create'),
                  semanticLabel: 'Create a listing',
                  fill: addWash.withAlpha(40),
                  border: addWash,
                  onTap: () {
                    AppHaptics.medium();
                    showCreateListingChooser(context);
                  },
                  child: const _WashIcon(
                    child: Icon(
                      Icons.add_rounded,
                      size: 23,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _HudButton(
                  key: const ValueKey('header-tokens'),
                  semanticLabel: 'Open tokens, balance $tokens',
                  fill: tokenWash.withAlpha(40),
                  border: tokenWash,
                  wide: true,
                  onTap: () {
                    AppHaptics.medium();
                    showGlassModal(
                      context: context,
                      builder: (_) => const TokensModal(),
                    );
                  },
                  child: _WashIcon(
                    badge: tokens > 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👑', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 5),
                        Text(
                          '$tokens',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-map'),
                  semanticLabel: 'Open map',
                  fill: mapWash.withAlpha(40),
                  border: mapWash,
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(overlayModalsProvider.notifier).openPassportMap();
                  },
                  child: const _WashIcon(
                    child: Icon(
                      Icons.public_rounded,
                      size: 21,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-theme'),
                  semanticLabel: isLight
                      ? 'Switch to dark appearance'
                      : 'Switch to light appearance',
                  fill: themeWash.withAlpha(40),
                  border: themeWash,
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(visualThemeProvider.notifier).toggle();
                  },
                  child: _WashIcon(
                    child: Icon(
                      isLight
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 21,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-notifications'),
                  semanticLabel: 'Open notifications',
                  fill: bellWash.withAlpha(40),
                  border: bellWash,
                  onTap: () {
                    AppHaptics.medium();
                    showGlassModal(
                      context: context,
                      builder: (_) => const NotificationsScreen(),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _WashIcon(
                        child: Icon(
                          Icons.notifications_rounded,
                          size: 21,
                          color: Colors.white,
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

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({
    super.key,
    required this.ink,
    required this.isLight,
    required this.onTap,
    this.avatarUrl,
    this.semanticLabel,
  });

  final String? avatarUrl;
  final Color ink;
  final bool isLight;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final border = Colors.white.withAlpha(isLight ? 125 : 72);
    final highlight = Colors.white.withAlpha(isLight ? 150 : 42);
    final lowlight = isLight
        ? Colors.white.withAlpha(120)
        : const Color(0xFF07070A).withAlpha(145);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 24 : 100),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: AppTopBar._hudSize,
                  height: AppTopBar._hudSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarUrl == null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [highlight, lowlight],
                          )
                        : null,
                    border: Border.all(color: border, width: 0.9),
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? Icon(Icons.person_rounded, size: 20, color: ink)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.fill,
    required this.border,
    this.wide = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color fill;
  final Color border;
  final bool wide;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final glassBorder = Colors.white.withAlpha(isLight ? 125 : 72);
    final highlight = Colors.white.withAlpha(isLight ? 150 : 42);
    final lowlight = isLight
        ? Colors.white.withAlpha(120)
        : const Color(0xFF07070A).withAlpha(145);
    final accent = Color.lerp(fill, border, 0.72) ?? border;

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
            splashColor: accent.withAlpha(55),
            highlightColor: Colors.white.withAlpha(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isLight ? 24 : 100),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                  BoxShadow(
                    color: accent.withAlpha(isLight ? 32 : 46),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: AppTopBar._hudSize,
                    width: wide ? null : AppTopBar._hudSize,
                    padding: wide
                        ? EdgeInsets.fromLTRB(
                            compact ? 8 : 10,
                            0,
                            compact ? 10 : 14,
                            0,
                          )
                        : null,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [highlight, lowlight],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: glassBorder, width: 0.9),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WashIcon extends StatelessWidget {
  const _WashIcon({required this.child, this.badge = false});

  final Widget child;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
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
