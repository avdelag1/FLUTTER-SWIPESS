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

/// Compact liquid-glass header. Controls stay crisp without dominating content.
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
  Size get preferredSize => const Size.fromHeight(64);

  static const addWash = Color(0xFFFF6F45);
  static const mapWash = Color(0xFF5B9CF6);
  static const themeWash = Color(0xFF9B7BFF);
  static const bellWash = Color(0xFFE95B9B);
  static const tokenWash = Color(0xFFE7A454);

  static const _hudSize = 38.0;

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
    final ink = isLight ? const Color(0xFF0D1117) : Colors.white;
    final tokens = ref.watch(tokenBalanceProvider);
    final compact = MediaQuery.sizeOf(context).width < 370;
    final chromeGap = compact ? 4.0 : 7.0;

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
                  accent: addWash,
                  onTap: () {
                    AppHaptics.medium();
                    showCreateListingChooser(context);
                  },
                  child: Icon(Icons.add_rounded, size: 23, color: ink),
                ),
              ],
            ),
            Row(
              children: [
                _HudButton(
                  key: const ValueKey('header-tokens'),
                  semanticLabel: 'Open tokens, balance $tokens',
                  accent: tokenWash,
                  wide: true,
                  onTap: () {
                    AppHaptics.medium();
                    showGlassModal(
                      context: context,
                      builder: (_) => const TokensModal(),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 3),
                      Text(
                        '$tokens',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-map'),
                  semanticLabel: 'Open map',
                  accent: mapWash,
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(overlayModalsProvider.notifier).openPassportMap();
                  },
                  child: Icon(Icons.public_rounded, size: 20, color: ink),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-theme'),
                  semanticLabel: isLight
                      ? 'Switch to dark appearance'
                      : 'Switch to light appearance',
                  accent: themeWash,
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(visualThemeProvider.notifier).toggle();
                  },
                  child: Icon(
                    isLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 20,
                    color: ink,
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-notifications'),
                  semanticLabel: 'Open notifications',
                  accent: bellWash,
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
                      Icon(Icons.notifications_none_rounded, size: 21, color: ink),
                      ref.watch(unreadNotificationsProvider).when(
                            data: (count) {
                              if (count <= 0) return const SizedBox.shrink();
                              return Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 7,
                                  height: 7,
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
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: AppTopBar._hudSize,
          height: AppTopBar._hudSize,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.white.withAlpha(190)
                      : Colors.white.withAlpha(26),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(isLight ? 150 : 92),
                    width: .9,
                  ),
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null
                    ? Icon(Icons.person_rounded, size: 19, color: ink)
                    : null,
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
    required this.accent,
    this.wide = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color accent;
  final bool wide;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final compact = MediaQuery.sizeOf(context).width < 370;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          splashColor: accent.withAlpha(48),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: AppTopBar._hudSize,
                width: wide ? null : AppTopBar._hudSize,
                padding: wide
                    ? EdgeInsets.symmetric(horizontal: compact ? 8 : 10)
                    : null,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.white.withAlpha(190)
                      : Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withAlpha(isLight ? 150 : 92),
                    width: .9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(isLight ? 18 : 34),
                      blurRadius: 9,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
