import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart'
    as legacy;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Launch wrapper around the existing Premium packages screen.
///
/// The legacy screen remains the billing/purchase authority. This wrapper adds
/// the Founding 100 campaign without inventing a fake scarcity counter: the
/// footer reads the live campaign row from Supabase and disappears when the
/// campaign is switched off (including automatically after the configured
/// redemption cap is reached once store redemptions are enabled).
class SubscriptionPackagesScreen extends ConsumerStatefulWidget {
  const SubscriptionPackagesScreen({super.key});

  @override
  ConsumerState<SubscriptionPackagesScreen> createState() =>
      _SubscriptionPackagesScreenState();
}

class _SubscriptionPackagesScreenState
    extends ConsumerState<SubscriptionPackagesScreen> {
  Map<String, dynamic>? _offer;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    try {
      final row = await Supabase.instance.client
          .from('premium_launch_offer_status')
          .select(
            'marketing_enabled,redemption_enabled,founding_cohort_size,buyer_cap,claimed_count',
          )
          .eq('offer_key', 'founding_100_double_time')
          .maybeSingle();
      if (!mounted) return;
      setState(() => _offer = row);
    } catch (_) {
      // Premium checkout must remain usable if campaign metadata is unavailable.
    }
  }

  int _intValue(String key, int fallback) =>
      ((_offer?[key] as num?)?.toInt() ?? fallback);

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider).value;
    final freemium = subscription?.isTrialActive == true;
    final paid =
        subscription != null &&
        subscription.tier != SubscriptionTier.free &&
        !freemium;

    final marketingEnabled = _offer?['marketing_enabled'] == true;
    final redemptionEnabled = _offer?['redemption_enabled'] == true;
    final foundingSize = _intValue('founding_cohort_size', 100);
    final cap = _intValue('buyer_cap', 50);
    final claimed = _intValue('claimed_count', 0).clamp(0, cap).toInt();
    final remaining = (cap - claimed).clamp(0, cap).toInt();

    // Paid members have already made their choice. When native-store redemption
    // is not active yet, only show the teaser to users who are still enjoying
    // the 3-month welcome window so nobody reaches checkout expecting an offer
    // that the store has not activated.
    final showLaunchOffer =
        marketingEnabled && !paid && (freemium || redemptionEnabled) && remaining > 0;

    if (!showLaunchOffer) {
      return const legacy.SubscriptionPackagesScreen();
    }

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: Column(
        children: [
          const Expanded(child: legacy.SubscriptionPackagesScreen()),
          _FoundingOfferFooter(
            foundingSize: foundingSize,
            cap: cap,
            remaining: remaining,
            freemium: freemium,
            redemptionEnabled: redemptionEnabled,
          ),
        ],
      ),
    );
  }
}

class _FoundingOfferFooter extends StatelessWidget {
  const _FoundingOfferFooter({
    required this.foundingSize,
    required this.cap,
    required this.remaining,
    required this.freemium,
    required this.redemptionEnabled,
  });

  final int foundingSize;
  final int cap;
  final int remaining;
  final bool freemium;
  final bool redemptionEnabled;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFEB4898).withAlpha(38),
              const Color(0xFF6366F1).withAlpha(24),
              MatteSurface.cardFill(context),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEB4898).withAlpha(100)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _LaunchPill(
                  label: 'FOUNDING $foundingSize',
                  background: const Color(0xFFEB4898),
                  foreground: Colors.white,
                ),
                const SizedBox(width: 7),
                _LaunchPill(
                  label: '$remaining / $cap BONUS SPOTS LEFT',
                  background: ink.withAlpha(12),
                  foreground: ink,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFEB4898),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FIRST $cap PAID UPGRADES GET 2× PREMIUM',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '1 month → 2 months  •  6 months → 12 months  •  1 year → 2 years',
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(220),
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              freemium
                  ? 'You already have the full Premium experience free during your 3-month welcome window. Use it first, learn the value, then decide whether to keep Premium.'
                  : 'Qualifying launch upgrades can claim the bonus while verified spots remain.',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 9.8,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              redemptionEnabled
                  ? 'The launch offer switches off automatically when all $cap verified bonus spots are claimed.'
                  : 'Offer eligibility and billing are confirmed at checkout. You do not need to pay while your free welcome window is active.',
              style: GoogleFonts.plusJakartaSans(
                color: muted.withAlpha(210),
                fontSize: 8.8,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaunchPill extends StatelessWidget {
  const _LaunchPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        color: foreground,
        fontSize: 7.8,
        fontWeight: FontWeight.w900,
        letterSpacing: .55,
      ),
    ),
  );
}
