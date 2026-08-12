import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor `LandingView` — wordmark, LOG IN, CREATE ACCOUNT, swipe-to-enter.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  double _dragX = 0;
  bool _triggered = false;

  void _enter(AuthIntent intent) {
    if (_triggered) return;
    _triggered = true;
    HapticFeedback.mediumImpact();
    ref.read(authIntentProvider.notifier).set(intent);
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final progress = (_dragX / 220).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _dragX = (_dragX + details.delta.dx).clamp(0, width);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      final shouldSwipe =
                          _dragX > 100 || (details.primaryVelocity ?? 0) > 400;
                      if (shouldSwipe) {
                        _enter(AuthIntent.login);
                      } else {
                        setState(() => _dragX = 0);
                      }
                    },
                    onTap: () => _enter(AuthIntent.login),
                    child: Opacity(
                      opacity: 1 - progress * 0.85,
                      child: Transform.scale(
                        scale: 1 - progress * 0.14,
                        child: Transform.translate(
                          offset: Offset(_dragX, 0),
                          child: const SwipessLogo(
                            height: 92,
                            variant: SwipessLogoVariant.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Column(
                      children: [
                        BrandPrimaryButton(
                          label: 'Log In',
                          icon: Icons.login_rounded,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          ringColor: Colors.white,
                          onPressed: () => _enter(AuthIntent.login),
                        ),
                        const SizedBox(height: 12),
                        BrandPrimaryButton(
                          label: 'Create Account',
                          icon: Icons.add_rounded,
                          onPressed: () => _enter(AuthIntent.signup),
                        ),
                        const SizedBox(height: 16),
                        _PulseHint(
                          child: Text(
                            'or swipe logo to enter →',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              fontSize: 9,
                              letterSpacing: 3.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseHint extends StatefulWidget {
  const _PulseHint({required this.child});

  final Widget child;

  @override
  State<_PulseHint> createState() => _PulseHintState();
}

class _PulseHintState extends State<_PulseHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.85).animate(_controller),
      child: widget.child,
    );
  }
}
