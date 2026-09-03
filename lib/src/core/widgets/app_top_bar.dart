import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/tokens_page.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';

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

  static const _hudHeight = 44.0;
  static const _hudWidth = 34.0;
  static const _chromeGap = 0.0;
  static const _chromeGapWide = 1.0;

  void _openProfile(BuildContext context) {
    AppHaptics.medium();
    if (onProfileTap != null) {
      onProfileTap!();
      return;
    }
    GoRouter.maybeOf(context)?.go(AppPaths.clientProfile);
  }

  void _backFromCurrent(BuildContext context) {
    NavBack.popOrGo(context, fallbackPath: AppPaths.clientDashboard);
  }

  void _openPremium(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    AppHaptics.medium();
    final currentPath = router.routeInformationProvider.value.uri.path;
    if (currentPath == AppPaths.subscriptionPackages) return;
    ref.read(overlayModalsProvider.notifier).closeAll();
    router.go(AppPaths.subscriptionPackages);
  }

  String get _label {
    final raw = firstName?.trim() ?? '';
    if (raw.isEmpty) return 'You';
    var s = raw.contains('@') ? raw.split('@').first : raw.split(' ').first;
    if (s.contains('.')) s = s.split('.').first;
    if (s.length > 10) s = '${s.substring(0, 9)}…';
    return s;
  }

  bool _sharedHeaderOwnsBack(String location) {
    if (location.isEmpty ||
        location == AppPaths.clientDashboard ||
        location == AppPaths.legacyDashboard) {
      return false;
    }
    return AppPaths.isShellLocation(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(isLightThemeProvider);
    final ink = isLight ? const Color(0xFF050608) : Colors.white;
    String location = '';
    try {
      location = GoRouterState.of(context).matchedLocation;
    } catch (_) {}
    final isProfileRoute =
        location == AppPaths.clientProfile || location == AppPaths.ownerProfile;
    final showHeaderBack = _sharedHeaderOwnsBack(location);

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
    final chromeGap = compact ? _chromeGap : _chromeGapWide;

    final isPublishing = ref.watch(addListingProvider).publishing;

    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _headerChrome(
            context,
            isLight: isLight,
            child: _headerRow(
              context,
              ref,
              ink: ink,
              isLight: isLight,
              isProfileRoute: isProfileRoute,
              showHeaderBack: showHeaderBack,
              chromeGap: chromeGap,
              tokensLabel: tokensLabel,
              tokenSemanticLabel: tokenSemanticLabel,
            ),
          ),
          if (isPublishing)
            Positioned(
              bottom: 0,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  color: AppTheme.brandPrimary,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerChrome(
    BuildContext context, {
    required bool isLight,
    required Widget child,
  }) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: preferredSize.height + top,
      padding: EdgeInsets.only(top: top + 6, left: 10, right: 10),
      decoration: BoxDecoration(
        color: AppTheme.canvasFor(isLight: isLight),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isLight ? 7 : 22),
            blurRadius: 20,
            spreadRadius: -10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _headerRow(
    BuildContext context,
    WidgetRef ref, {
    required Color ink,
    required bool isLight,
    required bool isProfileRoute,
    required bool showHeaderBack,
    required double chromeGap,
    required String tokensLabel,
    required String tokenSemanticLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHeaderBack)
                _HudButton(
                  key: const ValueKey('header-back'),
                  semanticLabel: 'Back to previous page',
                  onTap: () => _backFromCurrent(context),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: ink,
                  ),
                )
              else
                _HudButton(
                  key: const ValueKey('header-map'),
                  semanticLabel: 'Open map',
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(overlayModalsProvider.notifier).openPassportMap();
                  },
                  child: const _AnimatedWorldIcon(),
                ),
              SizedBox(width: chromeGap),
              _HudButton(
                key: const ValueKey('header-tokens'),
                semanticLabel:
                    'Open Direct Requests, available $tokenSemanticLabel',
                wide: true,
                onTap: () {
                  AppHaptics.light();
                  ref.read(overlayModalsProvider.notifier).closeAll();
                  showTokensPage(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.toll_rounded, size: 19, color: ink),
                    const SizedBox(width: 2),
                    Text(
                      tokensLabel,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.brandPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: chromeGap),
              _HudButton(
                key: const ValueKey('header-premium'),
                semanticLabel: 'Open Premium packages',
                onTap: () => _openPremium(context, ref),
                child: const _PremiumGlyph(),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HudButton(
              key: const ValueKey('header-notifications'),
              semanticLabel: 'Open notifications',
              onTap: () {
                AppHaptics.medium();
                ref.read(overlayModalsProvider.notifier).closeAll();
                showGlassModal(
                  context: context,
                  builder: (_) => const NotificationsScreen(),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 23, color: ink),
                  ref.watch(unreadNotificationsProvider).when(
                        data: (count) => count <= 0
                            ? const SizedBox.shrink()
                            : Positioned(
                                right: -8,
                                top: -7,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 17,
                                    minHeight: 17,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandPrimary,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: ink, width: 1.5),
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 8,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                ],
              ),
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
                isLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 22,
                color: ink,
              ),
            ),
            if (!isProfileRoute) ...[
              SizedBox(width: chromeGap),
              _ProfileAvatarButton(
                key: const ValueKey('header-profile'),
                avatarUrl: avatarUrl,
                seed: firstName ?? avatarUrl ?? 'swipess-you',
                semanticLabel: 'Open profile, $_label',
                onTap: () {
                  ref.read(overlayModalsProvider.notifier).closeAll();
                  _openProfile(context);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PremiumGlyph extends StatelessWidget {
  const _PremiumGlyph();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.brandPrimary, AppTheme.brandAccent2],
      ).createShader(bounds),
      child: const Icon(
        Icons.workspace_premium_rounded,
        size: 21,
        color: Colors.white,
      ),
    );
  }
}

class _ProfileAvatarButton extends StatefulWidget {
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
  State<_ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<_ProfileAvatarButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.semanticLabel,
        child: Tooltip(
          message: widget.semanticLabel ?? 'Profile',
          waitDuration: const Duration(milliseconds: 550),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            child: SizedBox(
              width: AppTopBar._hudWidth + 6,
              height: AppTopBar._hudHeight,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? .93 : 1,
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOutCubic,
                  child: FunAvatar(
                    seed: widget.seed,
                    imageUrl: widget.avatarUrl,
                    size: 30,
                    semanticLabel: widget.semanticLabel,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _HudButton extends StatefulWidget {
  const _HudButton({
    super.key,
    required this.child,
    required this.onTap,
    this.wide = false,
    this.accented = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool wide;
  final bool accented;
  final String? semanticLabel;

  @override
  State<_HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<_HudButton> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370;
    final neutral = Theme.of(context).colorScheme.onSurface;
    final Color surface;
    if (widget.accented) {
      surface = AppTheme.brandPrimary.withAlpha(
        _pressed ? 28 : (_hovered ? 17 : 8),
      );
    } else {
      surface = neutral.withAlpha(_pressed ? 19 : (_hovered ? 9 : 0));
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Tooltip(
        message: widget.semanticLabel ?? '',
        waitDuration: const Duration(milliseconds: 550),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            child: SizedBox(
              height: AppTopBar._hudHeight,
              width: widget.wide ? (compact ? 40 : 44) : AppTopBar._hudWidth,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 115),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: _pressed ? .91 : 1,
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOutCubic,
                    child: widget.child,
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

/// Natural earth-style map icon. No red/pink pulse: ocean is blue and land is
/// green so the map control reads instantly as a globe on every theme.
class _AnimatedWorldIcon extends StatelessWidget {
  const _AnimatedWorldIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.circle,
            size: 30,
            color: Color(0xFF2F80ED),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF43A047),
                Color(0xFF66BB6A),
                Color(0xFF2E7D32),
              ],
            ).createShader(bounds),
            child: const Icon(
              Icons.public_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
