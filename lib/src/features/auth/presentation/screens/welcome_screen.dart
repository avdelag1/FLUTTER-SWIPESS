import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/legendary_onboarding_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `LegendaryLandingPage` → `LandingView`.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  double _logoDx = 0;
  bool _triggered = false;
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

  void _enterAuth(String mode) {
    if (_triggered) return;
    _triggered = true;
    HapticFeedback.mediumImpact();
    context.push('${AppPaths.auth}?mode=$mode');
  }

  void _enterApp() {
    HapticFeedback.mediumImpact();
    context.go(AppPaths.legacyDashboard);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.brandPrimary),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
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
                            setState(() => _logoDx = (_logoDx + d.delta.dx)
                                .clamp(0, 240));
                          },
                          onHorizontalDragEnd: (d) {
                            final should =
                                _logoDx > 100 || d.velocity.pixelsPerSecond.dx > 400;
                            if (should) {
                              _enterAuth('login');
                              return;
                            }
                            setState(() => _logoDx = 0);
                          },
                          onTap: () => _enterAuth('login'),
                          child: Transform.translate(
                            offset: Offset(_logoDx, 0),
                            child: Opacity(
                              opacity: (1 - _logoDx / 220).clamp(0.35, 1),
                              child: const SwipessLogo(
                                height: 92,
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
                                      side: const BorderSide(color: Colors.white, width: 2),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: 18),
                                      SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          'SIGN IN',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    elevation: 0,
                                    shadowColor: AppTheme.brandPrimary,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, size: 18),
                                      SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          'CREATE ACCOUNT',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: _enterApp,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: const Text(
                                    'ENTER APP',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
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
