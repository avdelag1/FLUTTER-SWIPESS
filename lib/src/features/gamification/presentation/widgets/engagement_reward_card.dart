import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/providers/engagement_reward_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Profile-facing explanation of the SWIPESS active-use loyalty loop.
///
/// The exact cadence is intentionally not exposed in the UI. Users only see
/// their progress and the automatic reward outcome; the server remains the
/// source of truth for when a step is earned.
class EngagementRewardCard extends ConsumerWidget {
  const EngagementRewardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(engagementRewardProgressProvider);
    final progress = async.maybeWhen(
      data: (value) => value,
      orElse: () => const EngagementRewardProgress(),
    );
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withAlpha(24),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.bolt_rounded,
                color: AppTheme.brandPrimary,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVE REWARDS',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Use SWIPESS and unlock rewards automatically.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withAlpha(20),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF22C55E).withAlpha(70),
                ),
              ),
              child: Text(
                'AUTO',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF22C55E),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _RewardTrack(completed: progress.steps),
        const SizedBox(height: 14),
        Text(
          async.isLoading
              ? 'Syncing your reward progress…'
              : progress.steps == 4
                  ? '4/5 complete · Your next reward is close.'
                  : '${progress.steps}/5 complete · Keep exploring to unlock the next step.',
          style: GoogleFonts.plusJakartaSans(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Complete all 5 steps and your free token is added automatically.',
          style: GoogleFonts.plusJakartaSans(
            color: muted,
            fontSize: 10.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RewardTrack extends StatelessWidget {
  const _RewardTrack({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    final safe = completed.clamp(0, 5);

    return Row(
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: i <= safe
                      ? AppTheme.brandPrimary
                      : muted.withAlpha(35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: i == 5 ? 38 : 30,
            height: i == 5 ? 38 : 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: i <= safe
                  ? LinearGradient(
                      colors: i == 5
                          ? const [Color(0xFF7C3AED), Color(0xFFB04BFF)]
                          : const [Color(0xFFFF4D00), Color(0xFFFF7A00)],
                    )
                  : null,
              color: i <= safe ? null : muted.withAlpha(22),
              border: Border.all(
                color: i <= safe
                    ? Colors.white.withAlpha(35)
                    : muted.withAlpha(45),
              ),
              boxShadow: i <= safe
                  ? [
                      BoxShadow(
                        color: (i == 5
                                ? const Color(0xFF7C3AED)
                                : AppTheme.brandPrimary)
                            .withAlpha(35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: i == 5
                ? Icon(
                    Icons.card_giftcard_rounded,
                    size: 18,
                    color: i <= safe ? Colors.white : muted,
                  )
                : i <= safe
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        '$i',
                        style: GoogleFonts.plusJakartaSans(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
          ),
        ],
      ],
    );
  }
}
