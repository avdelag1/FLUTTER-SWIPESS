import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `SwipeErrorState` — connection failure on the deck.
class SwipeErrorState extends StatelessWidget {
  const SwipeErrorState({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
    this.isLight = false,
    this.message =
        'Could not load listings. Check your connection and try again.',
  });

  final VoidCallback onRetry;
  final bool isRetrying;
  final bool isLight;
  final String message;

  @override
  Widget build(BuildContext context) {
    final canvas = AppTheme.canvasFor(isLight: isLight);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final inkMuted =
        isLight ? const Color(0x990A0A0D) : Colors.white.withAlpha(153);
    final retryBorder = isLight ? Colors.black.withAlpha(64) : Colors.white;
    final retryShadow = isLight
        ? Colors.black.withAlpha(30)
        : Colors.black.withAlpha(102);

    return ColoredBox(
      color: canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0x26FB7185),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x4DFB7185)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFB7185),
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Connection issue',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: inkMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: isRetrying
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onRetry();
                      },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isRetrying ? 0.6 : 1,
                  child: Container(
                    height: 56,
                    constraints: const BoxConstraints(minWidth: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: retryBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: retryShadow,
                          blurRadius: 48,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRetrying)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ink,
                            ),
                          )
                        else
                          Icon(
                            Icons.refresh_rounded,
                            color: ink,
                            size: 18,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          isRetrying ? 'Retrying…' : 'Try again',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cap `SimpleSwipeCardSkeleton` — content-aware shimmer that mirrors the
/// real swipe card layout (photo well, position dots, verified/rating
/// pills, bottom price card, right action rail) instead of a blank box.
class SwipeLoadingSkeleton extends StatefulWidget {
  const SwipeLoadingSkeleton({super.key});

  @override
  State<SwipeLoadingSkeleton> createState() => _SwipeLoadingSkeletonState();
}

class _SwipeLoadingSkeletonState extends State<SwipeLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _pulse(double delay) {
    final t = (_controller.value + delay) % 1.0;
    return 0.55 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * t));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 56, 10, 78),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF0A0A0C)),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withAlpha(15)),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              // Diagonal shimmer sweep.
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final dx = -1.4 + _controller.value * 2.8;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(dx - 0.35, -1),
                        end: Alignment(dx + 0.35, 1),
                        colors: [
                          Colors.transparent,
                          Colors.white.withAlpha(12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Top position-indicator dots.
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: Container(
                        height: 2,
                        margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(i == 0 ? 89 : 20),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Verified badge placeholder.
              Positioned(
                left: 24,
                top: 90,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Opacity(
                    opacity: _pulse(0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 48,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Rating pill placeholder.
              Positioned(
                left: 20,
                bottom: 220,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Opacity(
                    opacity: _pulse(0.2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 32,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom price / info card.
              Positioned(
                left: 20,
                right: 20,
                bottom: 92,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x8C141418),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Color(0x8C000000), blurRadius: 32),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(width: 150, height: 18, delay: 0),
                          const SizedBox(width: 8),
                          _bar(width: 36, height: 14, delay: 0.1),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _bar(width: 120, height: 20, delay: 0.15),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _pill(width: 56, delay: 0.2),
                          const SizedBox(width: 8),
                          _pill(width: 48, delay: 0.25),
                          const SizedBox(width: 8),
                          _pill(width: 64, delay: 0.3),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _bar(width: 170, height: 11, delay: 0.35, alpha: 12),
                    ],
                  ),
                ),
              ),
              // Right-side action rail placeholder.
              Positioned(
                right: 12,
                bottom: 108,
                child: Column(
                  children: [
                    _dot(size: 52, delay: 0),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withAlpha(15)),
                      ),
                      child: Column(
                        children: List.generate(5, (i) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == 4 ? 0 : 8),
                            child: _dot(size: 44, delay: i * 0.08),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(
      {required double width,
      required double height,
      required double delay,
      int alpha = 26}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: _pulse(delay),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(alpha),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Widget _pill({required double width, required double delay}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: _pulse(delay),
        child: Container(
          width: width,
          height: 15,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _dot({required double size, required double delay}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: _pulse(delay),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
        ),
      ),
    );
  }
}
