import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Cap `LegendaryLandingPage` → `LandingView`.
/// Huge Mexican-red wordmark + white Sign In / Mexican-red Create Account.
/// Swiping or tapping the logo opens Sign In — never the dashboard.
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
    _launching = true;
    HapticFeedback.mediumImpact();
    ref.read(authIntentProvider.notifier).set(
          mode == 'signup' ? AuthIntent.signup : AuthIntent.login,
        );
    await context.push('${AppPaths.auth}?mode=$mode');
    if (!mounted) return;
    _launching = false;
    setState(() => _dragX = 0);
  }

  void _onLogoDragEnd(DragEndDetails details) {
    final shouldSwipe = _dragX > 80 || details.velocity.pixelsPerSecond.dx > 400;
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

    final width = MediaQuery.sizeOf(context).width;
    final logoWidth = (width * 0.94).clamp(320.0, 980.0);

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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _enterAuth('login'),
                            onHorizontalDragUpdate: (d) {
                              if (d.delta.dx <= 0 && _dragX <= 0) return;
                              setState(() => _dragX = (_dragX + d.delta.dx)
                                  .clamp(0.0, width));
                            },
                            onHorizontalDragEnd: _onLogoDragEnd,
                            child: Transform.translate(
                              offset: Offset(_dragX, 0),
                              child: Opacity(
                                opacity: (1 - (_dragX / 280)).clamp(0.35, 1),
                                child: SwipessLogo(
                                  width: logoWidth,
                                  variant: SwipessLogoVariant.hero,
                                  color: AppTheme.mexicanRed,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Column(
                              children: [
                                SwipessCtaButton(
                                  label: 'SIGN IN',
                                  icon: Icons.login_rounded,
                                  tone: SwipessCtaTone.white,
                                  onPressed: () => _enterAuth('login'),
                                ),
                                const SizedBox(height: 14),
                                SwipessCtaButton(
                                  label: 'CREATE ACCOUNT',
                                  icon: Icons.auto_awesome_rounded,
                                  tone: SwipessCtaTone.mexican,
                                  onPressed: () => _enterAuth('signup'),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'or swipe logo to enter  →',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 3.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => context.push(AppPaths.legal),
                        child: Text(
                          'Terms of Service',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(100),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '•',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(100),
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppPaths.legal),
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(100),
                            fontSize: 12,
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
