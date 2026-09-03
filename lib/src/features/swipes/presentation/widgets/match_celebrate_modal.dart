import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/core/native/app_review.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `MatchCelebrateModal` — mutual-match overlay with avatars + CTAs.
Future<void> showMatchCelebrateModal(
  BuildContext context, {
  required String clientName,
  String? clientImageUrl,
  String? ownerImageUrl,
  VoidCallback? onMessage,
}) {
  AppHaptics.heavy();
  unawaited(AppAudio.instance.playMatchFromPrefs());
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withAlpha(230),
    barrierLabel: 'Match',
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, _) {
      return _MatchCelebrateBody(
        clientName: clientName,
        clientImageUrl: clientImageUrl,
        ownerImageUrl: ownerImageUrl,
        onMessage: () {
          Navigator.of(ctx).pop();
          onMessage?.call();
        },
        onKeepSwiping: () => Navigator.of(ctx).pop(),
      );
    },
  );
}

class _MatchCelebrateBody extends StatefulWidget {
  const _MatchCelebrateBody({
    required this.clientName,
    required this.onMessage,
    required this.onKeepSwiping,
    this.clientImageUrl,
    this.ownerImageUrl,
  });

  final String clientName;
  final String? clientImageUrl;
  final String? ownerImageUrl;
  final VoidCallback onMessage;
  final VoidCallback onKeepSwiping;

  @override
  State<_MatchCelebrateBody> createState() => _MatchCelebrateBodyState();
}

class _MatchCelebrateBodyState extends State<_MatchCelebrateBody>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _confetti;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    final rng = math.Random(4);
    _particles = List.generate(48, (i) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble() * 0.35 - 0.05,
        vx: (rng.nextDouble() - 0.5) * 0.55,
        vy: 0.25 + rng.nextDouble() * 0.55,
        size: 3 + rng.nextDouble() * 5,
        color: [
          Colors.white,
          AppTheme.brandPrimary,
          const Color(0xFFFC567E),
          const Color(0xFFFBBF24),
        ][i % 4],
        delay: rng.nextDouble() * 0.35,
      );
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) AppHaptics.medium();
    });
    // Cap asks for a store review here: a mutual match is a genuine happy
    // moment. Gated to the 2nd+ match and 90-day spacing, so it cannot nag.
    AppReview().maybeRequestAfterMatch();
  }

  @override
  void dispose() {
    _enter.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.clientName.trim().split(' ').first;
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) {
              return CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  t: _confetti.value,
                ),
              );
            },
          ),
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _enter,
                curve: const Interval(0.05, 0.5, curve: Curves.easeOut),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MATCH',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -2,
                          height: 1,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Color(0x4DFFFFFF), blurRadius: 30),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "IT'S MUTUAL!",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(230),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                      SizedBox(height: 36),
                      SizedBox(
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: const Offset(-40, 0),
                              child: Transform.rotate(
                                angle: -0.14,
                                child: _AvatarCard(url: widget.clientImageUrl),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(40, 0),
                              child: Transform.rotate(
                                angle: 0.14,
                                child: _AvatarCard(url: widget.ownerImageUrl),
                              ),
                            ),
                            ScaleTransition(
                              scale: CurvedAnimation(
                                parent: _enter,
                                curve: const Interval(
                                  0.45,
                                  1,
                                  curve: Curves.elasticOut,
                                ),
                              ),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                    colors: [
                                      AppTheme.brandPrimary,
                                      Color(0xFFF43F5E),
                                      Color(0xFFFBBF24),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x99EA3F5E),
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'You and $first are now connected.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(204),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 36),
                      GestureDetector(
                        onTap: () {
                          AppHaptics.medium();
                          widget.onMessage();
                        },
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.transparent),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40FFFFFF),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.black,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'SAY HELLO',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      GestureDetector(
                        onTap: widget.onKeepSwiping,
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'KEEP SWIPING',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withAlpha(180),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 192,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.transparent, width: 6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url!.isNotEmpty)
            Image.network(
              url!,
              fit: BoxFit.cover,
              cacheWidth: 400,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF1E293B)),
            )
          else
            const ColoredBox(color: Color(0xFF1E293B)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.delay,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.t});

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final dx = (p.x + p.vx * local) * size.width;
      final dy = (p.y + p.vy * local) * size.height;
      final fade = (1 - local) * 0.95;
      canvas.drawCircle(
        Offset(dx, dy),
        p.size,
        Paint()..color = p.color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
