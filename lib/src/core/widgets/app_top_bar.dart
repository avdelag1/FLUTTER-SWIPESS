import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
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

  static const _hudSize = 44.0;

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
    final chromeGap = compact ? 0.0 : 1.0;

    final headerRow = _headerRow(
      context,
      ref,
      ink: ink,
      isLight: isLight,
      isProfileRoute: isProfileRoute,
      showHeaderBack: showHeaderBack,
      chromeGap: chromeGap,
      tokensLabel: tokensLabel,
      tokenSemanticLabel: tokenSemanticLabel,
    );

    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.none,
      child: _headerChrome(
        context,
        isLight: isLight,
        ink: ink,
        child: headerRow,
      ),
    );
  }

  Widget _headerChrome(
    BuildContext context, {
    required bool isLight,
    required Color ink,
    required Widget child,
  }) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: preferredSize.height + top,
      padding: EdgeInsets.only(top: top + 6, left: 10, right: 10),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withAlpha(kIsWeb ? 236 : 210)
            : const Color(0xE80D1015),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(color: ink.withAlpha(isLight ? 18 : 28)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isLight ? 8 : 40),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
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
                      ref
                          .read(overlayModalsProvider.notifier)
                          .openPassportMap();
                    },
                    child: _AnimatedWorldIcon(color: ink),
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
                SizedBox(width: chromeGap),
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
                          color: AppTheme.brandPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                onTap: () => _openProfile(context),
              ),
            ],
          ],
        ),
      ],
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
          width: wide ? (compact ? 44 : 48) : AppTopBar._hudSize,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _AnimatedWorldIcon extends StatefulWidget {
  const _AnimatedWorldIcon({required this.color});
  final Color color;

  @override
  State<_AnimatedWorldIcon> createState() => _AnimatedWorldIconState();
}

class _AnimatedWorldIconState extends State<_AnimatedWorldIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scheduleNextShine();
  }

  void _scheduleNextShine() {
    final delay = Duration(seconds: 8 + _random.nextInt(3));
    _timer = Timer(delay, () {
      if (mounted) {
        _controller.forward(from: 0).then((_) => _scheduleNextShine());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final intensity = math.sin(_controller.value * math.pi);
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.public_rounded, size: 22, color: widget.color),
            if (intensity > 0)
              Opacity(
                opacity: intensity,
                child: Icon(
                  Icons.public_rounded,
                  size: 22,
                  color: AppTheme.brandPrimary,
                ),
              ),
          ],
        );
      },
    );
  }
}
