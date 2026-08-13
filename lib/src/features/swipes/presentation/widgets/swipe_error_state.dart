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
    this.message =
        'Could not load listings. Check your connection and try again.',
  });

  final VoidCallback onRetry;
  final bool isRetrying;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0A0A0C),
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
                  color: Colors.white,
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
                  color: Colors.white.withAlpha(153),
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
                      border: Border.all(color: Colors.transparent),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 48,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRetrying)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          isRetrying ? 'Retrying…' : 'Try again',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
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

/// Invisible-feeling load (Cap skeleton returns null). On a pushed Flutter
/// route we still paint a dark card well so the screen is never blank.
class SwipeLoadingSkeleton extends StatelessWidget {
  const SwipeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 56, 10, 78),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.dashElevated,
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
        ),
      ),
    );
  }
}
