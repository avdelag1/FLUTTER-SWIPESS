import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_cta_button.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/legendary_onboarding_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Public landing surface matching the established Swipess black canvas.
/// The logo and account actions intentionally live as one compact visual group
/// so the page stays balanced on phones, tablets and web.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _checkingOnboarding = true;
  double _dragX = 0;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _maybeShowOnboarding();
  }

  Future<void> _maybeShowOnboarding() async {
    final done = await LegendaryOnboardingScreen.hasCompleted();
    if (!mounted) return;
    if (!done) {
      context.go(AppPaths.onboarding);
      return;
    }
    setState(() => _checkingOnboarding = false);
  }

  Future<void> _enterAuth(String mode) async {
    if (_launching) return;
    setState(() => _launching = true);
    AppHaptics.medium();
    ref
        .read(authIntentProvider.notifier)
        .set(mode == 'signup' ? AuthIntent.signup : AuthIntent.login);
    await context.push('${AppPaths.auth}?mode=$mode');
    if (!mounted) return;
    setState(() {
      _launching = false;
      _dragX = 0;
    });
  }

  void _onLogoDragEnd(DragEndDetails details) {
    final shouldSwipe =
        _dragX > 80 || details.velocity.pixelsPerSecond.dx > 400;
    if (shouldSwipe) {
      _enterAuth('login');
      return;
    }
    setState(() => _dragX = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.mexicanRed),
        ),
      );
    }

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final compactHeight = height < 680;
    final logoWidth = (width * 0.68).clamp(230.0, 430.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compactHeight ? 18 : 28,
                        24,
                        18,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              button: true,
                              label: 'Swipess logo. Tap or swipe right to sign in.',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _launching
                                    ? null
                                    : () => _enterAuth('login'),
                                onHorizontalDragUpdate: _launching
                                    ? null
                                    : (d) {
                                        if (d.delta.dx <= 0 && _dragX <= 0) {
                                          return;
                                        }
                                        setState(
                                          () => _dragX =
                                              (_dragX + d.delta.dx).clamp(
                                                0.0,
                                                width,
                                              ),
                                        );
                                      },
                                onHorizontalDragEnd:
                                    _launching ? null : _onLogoDragEnd,
                                child: Transform.translate(
                                  offset: Offset(_dragX, 0),
                                  child: Opacity(
                                    opacity: (1 - (_dragX / 300)).clamp(
                                      0.38,
                                      1,
                                    ),
                                    child: SwipessLogo(
                                      width: logoWidth,
                                      variant: SwipessLogoVariant.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: compactHeight ? 7 : 10),
                            Text(
                              'Swipe and find.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(145),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: compactHeight ? 18 : 22),
                            SwipessCtaButton(
                              label: 'SIGN IN',
                              icon: Icons.login_rounded,
                              tone: SwipessCtaTone.white,
                              onPressed: _launching
                                  ? null
                                  : () => _enterAuth('login'),
                            ),
                            const SizedBox(height: 11),
                            SwipessCtaButton(
                              label: 'CREATE ACCOUNT',
                              icon: Icons.person_add_alt_1_rounded,
                              tone: SwipessCtaTone.mexican,
                              onPressed: _launching
                                  ? null
                                  : () => _enterAuth('signup'),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swipe_right_alt_rounded,
                                  size: 16,
                                  color: Colors.white.withAlpha(90),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'swipe logo to enter →',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withAlpha(90),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: compactHeight ? 8 : 16,
                    left: 16,
                    right: 16,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 2,
                    children: [
                      TextButton(
                        onPressed: () => context.push(AppPaths.legal),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          'Terms',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(105),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '•',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(75),
                          fontSize: 11,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppPaths.legal),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          'Privacy',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(105),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
