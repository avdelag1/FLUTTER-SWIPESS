import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile/data/public_reputation_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class ReputationSignalsPanel extends ConsumerWidget {
  const ReputationSignalsPanel({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.trim().isEmpty) return const SizedBox.shrink();
    final async = ref.watch(publicReputationProvider(userId));
    return async.when(
      loading: () => const SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (reputation) {
        final chips = <Widget>[];
        if (reputation.verified) {
          chips.add(const _SignalChip(
            icon: Icons.verified_rounded,
            label: 'Verified',
          ));
        }
        if (reputation.averageRating != null && reputation.reviewCount > 0) {
          chips.add(_SignalChip(
            icon: Icons.star_rounded,
            label:
                '${reputation.averageRating!.toStringAsFixed(1)} · ${reputation.reviewCount} reviews',
          ));
        }
        if (reputation.responseRate != null) {
          chips.add(_SignalChip(
            icon: Icons.bolt_rounded,
            label: '${reputation.responseRate!.round()}% response rate',
          ));
        }
        if (reputation.connections > 0) {
          chips.add(_SignalChip(
            icon: Icons.handshake_outlined,
            label: '${reputation.connections} connections',
          ));
        }
        if (reputation.memberSinceYear != null) {
          chips.add(_SignalChip(
            icon: Icons.history_rounded,
            label: 'Member since ${reputation.memberSinceYear}',
          ));
        }
        if (chips.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRUST SIGNALS',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
            const SizedBox(height: 5),
            Text(
              'Based on visible account activity — not a hidden score.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white30,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
        color: Colors.white.withAlpha(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
