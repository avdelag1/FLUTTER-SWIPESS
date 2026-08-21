import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/payment_result_screen.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionPackagesScreen extends ConsumerStatefulWidget {
  const SubscriptionPackagesScreen({super.key});

  @override
  ConsumerState<SubscriptionPackagesScreen> createState() =>
      _SubscriptionPackagesScreenState();
}

class _SubscriptionPackagesScreenState
    extends ConsumerState<SubscriptionPackagesScreen> {
  String? _buyingId;
  bool _restoring = false;

  Future<void> _buy(IapOffer offer) async {
    if (_buyingId != null) return;
    setState(() => _buyingId = offer.id);
    AppHaptics.medium();
    final result = await ref.read(paymentServiceProvider).buy(offer);
    if (!mounted) return;
    setState(() => _buyingId = null);
    ref.invalidate(messagingEntitlementsProvider);
    ref.invalidate(directRequestBalanceProvider);
    ref.invalidate(subscriptionProvider);
    if (result.isSuccess) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaymentResultScreen(success: true),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final result = await ref.read(paymentServiceProvider).restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    ref.invalidate(messagingEntitlementsProvider);
    ref.invalidate(directRequestBalanceProvider);
    ref.invalidate(subscriptionProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final current = ref.watch(subscriptionProvider).value;
    final balance = ref.watch(directRequestBalanceProvider).value;
    final premiumActive = current?.effectiveTier != SubscriptionTier.free;

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _restoring ? null : _restore,
                    child: Text(_restoring ? 'Restoring…' : 'Restore Purchases'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  Text(
                    'GET MORE FROM\nSWIPESS',
                    textAlign: TextAlign.center,
                    style: SwipessTokens.displayItalic(color: ink, fontSize: 34),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'More speed. More visibility. More opportunities.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _principleCard(context),
                  const SizedBox(height: 16),
                  if (premiumActive || current?.isTrialActive == true)
                    _accessCard(
                      context,
                      title: current?.isTrialActive == true
                          ? 'PREMIUM WELCOME ACCESS — ACTIVE'
                          : 'PREMIUM — ACTIVE',
                      subtitle: balance == null
                          ? 'Your Premium advantages are active.'
                          : '${balance.available} Direct Requests available now.',
                      benefits: const [
                        'Matched chats remain free',
                        'Premium listing, AI and visibility advantages',
                        'Direct Requests use the same fair accept/return rule',
                      ],
                      accent: SwipessTokens.tierPower,
                    )
                  else
                    _accessCard(
                      context,
                      title: 'FREE — START HERE',
                      subtitle: 'Swipess works without a subscription.',
                      benefits: const [
                        'Browse and swipe freely',
                        'Right swipe = free interest',
                        'Mutual match = free chat',
                        '1 active listing',
                        'Use Direct Requests only when you want priority',
                      ],
                      accent: ink,
                    ),
                  const SizedBox(height: 26),
                  for (var i = 0; i < IapCatalog.subscriptions.length; i++) ...[
                    _planCard(
                      context,
                      offer: IapCatalog.subscriptions[i],
                      index: i,
                    ),
                    if (i != IapCatalog.subscriptions.length - 1)
                      const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Not ready for Premium? No problem. Swipess still works for free — use a Direct Request token only when something matters enough to skip the wait.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _principleCard(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: ink.withAlpha(12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ink.withAlpha(28)),
      ),
      child: Column(
        children: [
          Text(
            'INTEREST IS FREE. MATCHES ARE FREE.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Premium gives you more priority, reach, AI and scale — it never buys permission to force-message somebody.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> benefits,
    required Color accent,
  }) {
    final ink = MatteSurface.ink(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withAlpha(80)),
        color: accent.withAlpha(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          for (final benefit in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '✓ $benefit',
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _planCard(
    BuildContext context, {
    required IapOffer offer,
    required int index,
  }) {
    final ink = MatteSurface.ink(context);
    final accent = offer.popular
        ? SwipessTokens.tierPlus
        : index == 0
            ? SwipessTokens.tierStarter
            : SwipessTokens.tierPower;
    final audience = switch (index) {
      0 => 'Travelers, short stays & active users',
      1 => 'Residents, nomads, workers & frequent users',
      _ => 'Owners, professionals & businesses',
    };
    final promise = switch (index) {
      0 => 'Full power while you’re here.',
      1 => 'The best choice if this is home for a while.',
      _ => 'Make Swipess work for you.',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accent.withAlpha(offer.popular ? 150 : 70),
          width: offer.popular ? 1.5 : 1,
        ),
        color: accent.withAlpha(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (offer.label ?? offer.name).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              if (offer.popular)
                Text(
                  'MOST POPULAR',
                  style: GoogleFonts.plusJakartaSans(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${offer.priceLabel} ${offer.durationLabel ?? ''}',
            style: SwipessTokens.priceOversized(color: ink, fontSize: 34),
          ),
          const SizedBox(height: 5),
          Text(
            promise,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Best for: $audience',
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          for (final benefit in offer.benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: accent, size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      benefit,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _buyingId == null ? () => _buy(offer) : null,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: _buyingId == offer.id
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(index == 2 ? 'GO PRO' : 'GET PREMIUM'),
            ),
          ),
        ],
      ),
    );
  }
}
