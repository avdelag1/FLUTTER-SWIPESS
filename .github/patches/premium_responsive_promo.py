from pathlib import Path

v3 = Path('lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart')
text = v3.read_text()

old_ctor = """class SubscriptionPackagesScreen extends ConsumerStatefulWidget {
  const SubscriptionPackagesScreen({super.key});

  @override
"""
new_ctor = """class SubscriptionPackagesScreen extends ConsumerStatefulWidget {
  const SubscriptionPackagesScreen({
    super.key,
    this.launchOfferActive = false,
    this.launchFoundingSize = 100,
    this.launchBuyerCap = 0,
    this.launchClaimed = 0,
  });

  final bool launchOfferActive;
  final int launchFoundingSize;
  final int launchBuyerCap;
  final int launchClaimed;

  @override
"""
if old_ctor not in text:
    raise SystemExit('v3 constructor block not found')
text = text.replace(old_ctor, new_ctor, 1)

old_padding = "padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),"
new_padding = """padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.sizeOf(context).width >= 700 ? 34 : 12,
                  20,
                  44,
                ),"""
if old_padding not in text:
    raise SystemExit('v3 list padding not found')
text = text.replace(old_padding, new_padding, 1)

old_title = """                  Text(
                    '3 MONTHS FREEMIUM.\\nTHEN YOU DECIDE.',
                    textAlign: TextAlign.center,
                    style: SwipessTokens.displayItalic(
                      color: ink,
                      fontSize: 33,
                    ),
                  ),"""
new_title = """                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '3 MONTHS FREEMIUM.\\nTHEN YOU DECIDE.',
                          maxLines: 2,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: SwipessTokens.displayItalic(
                            color: ink,
                            fontSize: 33,
                          ),
                        ),
                      ),
                    ),
                  ),"""
if old_title not in text:
    raise SystemExit('v3 hero title block not found')
text = text.replace(old_title, new_title, 1)

old_call = """                    _PlanCard(
                      offer: offer,
                      buying: _buyingId == offer.id,
                      onBuy: () => _buy(offer),
                    ),"""
new_call = """                    _PlanCard(
                      offer: offer,
                      buying: _buyingId == offer.id,
                      onBuy: () => _buy(offer),
                      launchOfferActive: widget.launchOfferActive,
                      launchFoundingSize: widget.launchFoundingSize,
                      launchBuyerCap: widget.launchBuyerCap,
                      launchClaimed: widget.launchClaimed,
                    ),"""
if old_call not in text:
    raise SystemExit('v3 plan call not found')
text = text.replace(old_call, new_call, 1)

old_plan_ctor = """class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.offer,
    required this.buying,
    required this.onBuy,
  });

  final IapOffer offer;
  final bool buying;
  final VoidCallback onBuy;
"""
new_plan_ctor = """class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.offer,
    required this.buying,
    required this.onBuy,
    required this.launchOfferActive,
    required this.launchFoundingSize,
    required this.launchBuyerCap,
    required this.launchClaimed,
  });

  final IapOffer offer;
  final bool buying;
  final VoidCallback onBuy;
  final bool launchOfferActive;
  final int launchFoundingSize;
  final int launchBuyerCap;
  final int launchClaimed;
"""
if old_plan_ctor not in text:
    raise SystemExit('v3 plan constructor not found')
text = text.replace(old_plan_ctor, new_plan_ctor, 1)

marker = 'class _PlanCard extends StatelessWidget'
before, plan = text.split(marker, 1)
old_insert = """          const SizedBox(height: 14),
          for (final benefit in offer.benefits) _Check(benefit),"""
new_insert = """          if (launchOfferActive && launchBuyerCap > 0) ...[
            const SizedBox(height: 12),
            _LaunchOfferStrip(
              offer: offer,
              foundingSize: launchFoundingSize,
              buyerCap: launchBuyerCap,
              claimed: launchClaimed,
            ),
          ],
          const SizedBox(height: 14),
          for (final benefit in offer.benefits) _Check(benefit),"""
if old_insert not in plan:
    raise SystemExit('v3 plan benefits insertion point not found')
plan = plan.replace(old_insert, new_insert, 1)
text = before + marker + plan

class_marker = '\nclass _InfoCard extends StatelessWidget {'
promo_class = r'''

class _LaunchOfferStrip extends StatelessWidget {
  const _LaunchOfferStrip({
    required this.offer,
    required this.foundingSize,
    required this.buyerCap,
    required this.claimed,
  });

  final IapOffer offer;
  final int foundingSize;
  final int buyerCap;
  final int claimed;

  String get _doubleTimeLabel {
    if (offer.id.contains('1-month')) return '1 MONTH → 2 MONTHS';
    if (offer.id.contains('6-months')) return '6 MONTHS → 12 MONTHS';
    if (offer.id.contains('1-year')) return '1 YEAR → 2 YEARS';
    return '2× PREMIUM TIME';
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final safeClaimed = claimed.clamp(0, buyerCap).toInt();
    final remaining = (buyerCap - safeClaimed).clamp(0, buyerCap).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEB4898).withAlpha(34),
            const Color(0xFF6366F1).withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEB4898).withAlpha(95)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                label: 'FOUNDING $foundingSize',
                background: const Color(0xFFEB4898),
                foreground: Colors.white,
              ),
              _Pill(
                label: '$remaining OF $buyerCap PURCHASES LEFT',
                background: ink.withAlpha(12),
                foreground: ink,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'LIMITED 2-FOR-1 · $_doubleTimeLabel',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'First $buyerCap verified purchases receive 2× the Premium duration. $safeClaimed/$buyerCap purchases claimed.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 9.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
'''
if class_marker not in text:
    raise SystemExit('v3 info card marker not found')
text = text.replace(class_marker, promo_class + class_marker, 1)
v3.write_text(text)

v4 = Path('lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v4.dart')
v4.write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart'
    as legacy;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adds the live Founding 100 / 2-for-1 campaign data to the package cards.
/// Purchase counts are real verified campaign counts from Supabase.
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

    final marketingEnabled = _offer?['marketing_enabled'] == true;
    final redemptionEnabled = _offer?['redemption_enabled'] == true;
    final foundingSize = _intValue('founding_cohort_size', 100);
    final cap = _intValue('buyer_cap', 50);
    final claimed = _intValue('claimed_count', 0).clamp(0, cap).toInt();
    final remaining = (cap - claimed).clamp(0, cap).toInt();
    final showLaunchOffer =
        marketingEnabled &&
        !paid &&
        (freemium || redemptionEnabled) &&
        remaining > 0;

    return legacy.SubscriptionPackagesScreen(
      launchOfferActive: showLaunchOffer,
      launchFoundingSize: foundingSize,
      launchBuyerCap: cap,
      launchClaimed: claimed,
    );
  }
}
''')
