import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/boot_splash.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/legendary_onboarding_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `LegendaryLandingPage` → `LandingView`.
/// Two CTAs only: SIGN IN + CREATE ACCOUNT. No "ENTER APP".
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  double _logoDx = 0;
  bool _swipeArmed = false;
  bool _checkingOnboarding = true;

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

  void _enterAuth(String mode, {bool fromSwipe = false}) {
    if (fromSwipe) {
      if (_swipeArmed) return;
      _swipeArmed = true;
    }
    HapticFeedback.mediumImpact();
    context.push('${AppPaths.auth}?mode=$mode');
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) return const BootSplash();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onHorizontalDragUpdate: (d) {
                            setState(() => _logoDx =
                                (_logoDx + d.delta.dx).clamp(0, 240));
                          },
                          onHorizontalDragEnd: (d) {
                            final should = _logoDx > 100 ||
                                d.velocity.pixelsPerSecond.dx > 400;
                            if (should) {
                              _enterAuth('login', fromSwipe: true);
                              return;
                            }
                            setState(() => _logoDx = 0);
                          },
                          onTap: () => _enterAuth('login', fromSwipe: true),
                          child: Transform.translate(
                            offset: Offset(_logoDx, 0),
                            child: Opacity(
                              opacity: (1 - _logoDx / 220).clamp(0.35, 1),
                              child: const SwipessLogo(
                                width: 340,
                                variant: SwipessLogoVariant.transparent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 56),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () => _enterAuth('login'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      side: BorderSide(
                                        color: Colors.white.withAlpha(230),
                                        width: 2,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, size: 18),
                                        SizedBox(width: 10),
                                        Text(
                                          'SIGN IN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () => _enterAuth('signup'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.brandPrimary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    elevation: 0,
                                    shadowColor: AppTheme.brandPrimary,
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded, size: 18),
                                        SizedBox(width: 10),
                                        Text(
                                          'CREATE ACCOUNT',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'or swipe logo to enter →',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withAlpha(180),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.2,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => context.push(AppPaths.legal),
                        child: Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '•',
                        style: TextStyle(
                          color: Colors.white.withAlpha(100),
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppPaths.legal),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
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
