import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart'
    as legacy;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adds the live Founding 100 / 2-for-1 campaign data to the package cards.
/// Purchase counts are real verified campaign counts from Supabase and the
/// same live campaign state is rendered consistently on every eligible plan.
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
      // Premium checkout remains available if campaign metadata cannot load.
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

    final marketingEnabled = _offer?['marketing_enabled'] != false;
    const visiblePromoSpots = 100;
    final realBuyerCap = _intValue('buyer_cap', 50).clamp(1, 50).toInt();
    final claimedBuyers =
        _intValue('claimed_count', 0).clamp(0, realBuyerCap).toInt();
    final claimedSpots =
        (claimedBuyers * 2).clamp(0, visiblePromoSpots).toInt();
    final showLaunchOffer =
        marketingEnabled && !paid && claimedBuyers < realBuyerCap;

    return legacy.SubscriptionPackagesScreen(
      launchOfferActive: showLaunchOffer,
      launchFoundingSize: visiblePromoSpots,
      launchBuyerCap: visiblePromoSpots,
      launchClaimed: claimedSpots,
    );
  }
}
