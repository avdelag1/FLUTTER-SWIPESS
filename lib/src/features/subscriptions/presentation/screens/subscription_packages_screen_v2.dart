import 'dart:async';

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
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

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

  String _remainingLabel(DateTime? end) {
    if (end == null) return '3 MONTHS';
    final remaining = end.toUtc().difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return 'ENDED';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    if (days > 0) return '$days DAYS  $hours HRS LEFT';
    final minutes = remaining.inMinutes.remainder(60);
    return '${remaining.inHours} HRS  $minutes MIN LEFT';
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final current = ref.watch(subscriptionProvider).value;
    final balance = ref.watch(directRequestBalanceProvider).value;
    final trialActive = current?.isTrialActive == true;
    final paidActive = current != null &&
        current.tier != SubscriptionTier.free &&
        !trialActive;
    final currentBalance = balance?.available;

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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
                children: [
                  Text(
                    'FREEMIUM NOW.\nPREMIUM WHEN YOU NEED IT.',
                    textAlign: TextAlign.center,
                    style: SwipessTokens.displayItalic(color: ink, fontSize: 32),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Your welcome period is simple: 3 months of full Premium feature access, then choose a plan only if you want to keep the Premium tools.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w650,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (trialActive)
                    _FreemiumCard(
                      countdown: _remainingLabel(current?.trialEndsAt),
                      currentBalance: currentBalance,
                    )
                  else if (paidActive)
                    _PaidActiveCard(
                      tier: current!.tier,
                      currentBalance: currentBalance,
                    )
                  else
                    _FreeCard(currentBalance: currentBalance),

                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PREMIUM PACKAGES',
                          style: SwipessTokens.kickerUppercase(
                            color: ink.withAlpha(155),
                          ),
                        ),
                      ),
                      Text(
                        '20 · 50 · 150 REQUESTS',
                        style: GoogleFonts.plusJakartaSans(
                          color: muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < IapCatalog.subscriptions.length; i++) ...[
                    _PlanCard(
                      offer: IapCatalog.subscriptions[i],
                      buying: _buyingId == IapCatalog.subscriptions[i].id,
                      onBuy: () => _buy(IapCatalog.subscriptions[i]),
                    ),
                    if (i != IapCatalog.subscriptions.length - 1)
                      const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MatteSurface.cardFill(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: MatteSurface.hairline(context)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'WHAT STAYS FREE',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Browsing and swiping, mutual matches and matched chat remain free. Your Virtual / Local ID card also remains free permanently. After Freemium ends, AI, Legal, Events and Premium listing/visibility advantages require a Premium package.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: muted,
                            fontSize: 11.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
}

class _FreemiumCard extends StatelessWidget {
  const _FreemiumCard({required this.countdown, required this.currentBalance});

  final String countdown;
  final int? currentBalance;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEB4898).withAlpha(34),
            const Color(0xFF6366F1).withAlpha(24),
            MatteSurface.cardFill(context),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEB4898).withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEB4898),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '3-MONTH FREEMIUM',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'ACTIVE',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF22C55E),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            countdown,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 27,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The countdown runs continuously from the beginning of your 3-month welcome window.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'YOU HAVE THE YEARLY / UNLIMITED FEATURE EXPERIENCE DURING FREEMIUM',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .65,
            ),
          ),
          const SizedBox(height: 10),
          const _Benefit('AI + AI Listing Creator'),
          const _Benefit('Legal Hub, document creation and Swipess Sign'),
          const _Benefit('Events discovery and access'),
          const _Benefit('Maximum listing capacity + Premium visibility'),
          const _Benefit('Priority matching / Premium feature advantages'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: ink.withAlpha(8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MatteSurface.hairline(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME DIRECT REQUESTS',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '5 included once when your Freemium starts.',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (currentBalance != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Current balance: $currentBalance. Your balance can be higher than 5 because you can earn additional Direct Requests through app activity/referrals or buy more separately.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 10.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Virtual / Local ID is not a Premium lock — it stays free for everyone after the countdown too.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidActiveCard extends StatelessWidget {
  const _PaidActiveCard({required this.tier, required this.currentBalance});

  final SubscriptionTier tier;
  final int? currentBalance;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREMIUM ACTIVE',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currentBalance == null
                      ? 'Your paid Premium benefits are active.'
                      : '$currentBalance Direct Requests available now.',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeCard extends StatelessWidget {
  const _FreeCard({required this.currentBalance});
  final int? currentBalance;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FREE',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Browse, swipe, match, chat and keep your Virtual / Local ID free. Upgrade to restore AI, Legal, Events and Premium listing advantages.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 11.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (currentBalance != null) ...[
            const SizedBox(height: 8),
            Text(
              '$currentBalance Direct Requests available.',
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.offer,
    required this.buying,
    required this.onBuy,
  });

  final IapOffer offer;
  final bool buying;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final isYearly = offer.id.contains('1-year');
    final accent = isYearly
        ? const Color(0xFFEB4898)
        : offer.popular
            ? const Color(0xFF6366F1)
            : ink;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isYearly || offer.popular
              ? accent.withAlpha(105)
              : MatteSurface.hairline(context),
          width: isYearly ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          offer.name.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (isYearly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEB4898),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'UNLIMITED',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      offer.label ?? 'PREMIUM',
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    offer.priceLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    offer.durationLabel ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          for (final benefit in offer.benefits) _Benefit(benefit),
          const SizedBox(height: 13),
          Text(
            'Direct Requests are included with the package and are separate from matched chat, which stays free.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 9.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: buying ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isYearly || offer.popular
                    ? Colors.white
                    : (MatteSurface.isLight(context) ? Colors.white : Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: buying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'CHOOSE ${offer.name.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .6,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF22C55E)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(215),
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w650,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
