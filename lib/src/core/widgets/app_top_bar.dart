import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
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

  static const _hudSize = 39.0;

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
    final ink = isLight ? const Color(0xFF050608) : Colors.white;

    final directRequests = ref.watch(directRequestBalanceProvider);
    final tokensLabel = directRequests.when(
      data: (balance) => '${balance.available}',
      loading: () => '…',
      error: (_, _) => '—',
    );
    final tokenSemanticLabel = directRequests.maybeWhen(
      data: (balance) => '${balance.available}',
      orElse: () => 'loading',
    );

    final compact = MediaQuery.sizeOf(context).width < 370;
    final chromeGap = compact ? 0.0 : 1.0;

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
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileAvatarButton(
                  key: const ValueKey('header-profile'),
                  avatarUrl: avatarUrl,
                  seed: firstName ?? avatarUrl ?? 'swipess-you',
                  semanticLabel: 'Open profile, $_label',
                  onTap: () => _openProfile(context),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-create'),
                  semanticLabel: 'Create a listing',
                  onTap: () {
                    AppHaptics.medium();
                    showCreateListingChooser(context);
                  },
                  child: Icon(Icons.add_rounded, size: 25, color: ink),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HudButton(
                  key: const ValueKey('header-tokens'),
                  semanticLabel:
                      'Open Direct Requests, available $tokenSemanticLabel',
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
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 21,
                        color: ink,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        tokensLabel,
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
                  key: const ValueKey('header-map'),
                  semanticLabel: 'Open map',
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(overlayModalsProvider.notifier).openPassportMap();
                  },
                  child: Icon(Icons.public_rounded, size: 22, color: ink),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-theme'),
                  semanticLabel: isLight
                      ? 'Switch to dark appearance'
                      : 'Switch to light appearance',
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(visualThemeProvider.notifier).toggle();
                  },
                  child: Icon(
                    isLight
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 22,
                    color: ink,
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-notifications'),
                  semanticLabel: 'Open notifications',
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
                        size: 23,
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
    super.key,
    required this.onTap,
    required this.seed,
    this.avatarUrl,
    this.semanticLabel,
  });

  final String? avatarUrl;
  final String seed;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: AppTopBar._hudSize,
            height: AppTopBar._hudSize,
            child: Center(
              child: FunAvatar(
                seed: seed,
                imageUrl: avatarUrl,
                size: 32,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ),
      );
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    super.key,
    required this.child,
    required this.onTap,
    this.wide = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool wide;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: AppTopBar._hudSize,
          width: wide ? (compact ? 43 : 46) : AppTopBar._hudSize,
          child: Center(child: child),
        ),
      ),
    );
  }
}
