import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_countdown.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Live months · days · hours countdown for freemium trial and paid packages.
class MembershipCountdownCard extends ConsumerStatefulWidget {
  const MembershipCountdownCard({super.key});

  @override
  ConsumerState<MembershipCountdownCard> createState() =>
      _MembershipCountdownCardState();
}

class _MembershipCountdownCardState
    extends ConsumerState<MembershipCountdownCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider).value;
    if (subscription == null || !subscription.hasLiveCountdown) {
      return const SizedBox.shrink();
    }

    final parts = subscriptionCountdownParts(subscription.accessEndsAt);
    if (parts.expired) return const SizedBox.shrink();

    final subtitle = subscription.isTrialActive
        ? 'Your complimentary 3-month Premium window is counting down live.'
        : 'Your ${subscription.membershipCountdownLabel.toLowerCase()} renews when this timer reaches zero.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(AppPaths.subscriptionPackages),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFEB4898).withAlpha(56),
                  const Color(0xFF6366F1).withAlpha(34),
                  const Color(0xFF151821),
                ],
              ),
              border: Border.all(color: const Color(0xFFEB4898).withAlpha(110)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEB4898),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        subscription.membershipCountdownLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  parts.compactLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  parts.sentenceLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
