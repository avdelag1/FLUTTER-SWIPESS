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
  Size get preferredSize => const Size.fromHeight(58);

  static const addWash = Color(0xFFFF6F45);
  static const mapWash = Color(0xFF5B9CF6);
  static const themeWash = Color(0xFF9B7BFF);
  static const bellWash = Color(0xFFE95B9B);
  static const tokenWash = Color(0xFFD7A83E);
  static const tokenGold = Color(0xFFF2C14E);
  static const tokenGoldDeep = Color(0xFFB87916);
  static const _hudSize = 34.0;

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
    final chromeGap = compact ? 3.0 : 5.0;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: preferredSize.height + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 6,
          left: 10,
          right: 10,
        ),
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _ProfileAvatarButton(
                  avatarUrl: avatarUrl,
                  ink: ink,
                  isLight: isLight,
                  semanticLabel: 'Open profile, $_label',
                  onTap: () => _openProfile(context),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  semanticLabel: 'Create a listing',
                  accent: addWash,
                  onTap: () {
                    AppHaptics.medium();
                    showCreateListingChooser(context);
                  },
                  child: Icon(Icons.add_rounded, size: 21, color: ink),
                ),
              ],
            ),
            Row(
              children: [
                _HudButton(
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
                      Container(
                        width: 21,
                        height: 21,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFE08A),
                              tokenGold,
                              tokenGoldDeep,
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFE6A6),
                            width: .7,
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 13,
                          color: Color(0xFF3A2608),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$tokens',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  semanticLabel: 'Open map',
                  accent: mapWash,
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(overlayModalsProvider.notifier).openPassportMap();
                  },
                  child: Icon(Icons.public_rounded, size: 18, color: ink),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  semanticLabel: isLight
                      ? 'Switch to dark appearance'
                      : 'Switch to light appearance',
                  accent: themeWash,
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(visualThemeProvider.notifier).toggle();
                  },
                  child: Icon(
                    isLight
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 18,
                    color: ink,
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
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
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 19,
                        color: ink,
                      ),
                      ref.watch(unreadNotificationsProvider).when(
                            data: (count) => count <= 0
                                ? const SizedBox.shrink()
                                : const Positioned(
                                    right: -1,
                                    top: -1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandPrimary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: SizedBox(width: 7, height: 7),
                                    ),
                                  ),
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: AppTopBar._hudSize,
            height: AppTopBar._hudSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? const [
                        Color(0xFAFFFFFF),
                        Color(0xE6E4EBF2),
                        Color(0xF5FFFFFF),
                      ]
                    : const [
                        Color(0xF0444B55),
                        Color(0xEA20262F),
                        Color(0xF02E3540),
                      ],
                stops: const [0, .58, 1],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isLight
                    ? Colors.white.withAlpha(235)
                    : Colors.white.withAlpha(105),
                width: .9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 20 : 62),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withAlpha(isLight ? 90 : 18),
                  blurRadius: 4,
                  offset: const Offset(-1, -1),
                ),
              ],
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null
                ? Icon(Icons.person_rounded, size: 17, color: ink)
                : null,
          ),
        ),
      );
}

class _HudButton extends StatelessWidget {
  const _HudButton({
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
          splashColor: accent.withAlpha(34),
          child: Container(
            height: AppTopBar._hudSize,
            width: wide ? null : AppTopBar._hudSize,
            padding: wide
                ? EdgeInsets.symmetric(horizontal: compact ? 7 : 9)
                : null,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Static frozen-glass surface: layered icy highlights without a
              // live backdrop filter over the dashboard/video content.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? const [
                        Color(0xFAFFFFFF),
                        Color(0xE6E4EBF2),
                        Color(0xF5FFFFFF),
                      ]
                    : const [
                        Color(0xF0444B55),
                        Color(0xEA20262F),
                        Color(0xF02E3540),
                      ],
                stops: const [0, .58, 1],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isLight
                    ? Colors.white.withAlpha(235)
                    : Colors.white.withAlpha(105),
                width: .9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 20 : 62),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withAlpha(isLight ? 90 : 18),
                  blurRadius: 4,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
