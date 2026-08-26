import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
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
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.userMessage)));
    }
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.userMessage)));
  }

  String _countdown(DateTime? endsAt) {
    if (endsAt == null) return '3 MONTHS';
    final left = endsAt.toUtc().difference(DateTime.now().toUtc());
    if (left <= Duration.zero) return 'ENDED';
    final days = left.inDays;
    final hours = left.inHours.remainder(24);
    if (days > 0) return '$days DAYS · $hours HRS LEFT';
    return '${left.inHours} HRS · ${left.inMinutes.remainder(60)} MIN LEFT';
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final subscription = ref.watch(subscriptionProvider).value;
    final balance = ref.watch(directRequestBalanceProvider).value?.available;
    final freemium = subscription?.isTrialActive == true;
    final paid =
        subscription != null &&
        subscription.tier != SubscriptionTier.free &&
        !freemium;

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
              child: Row(
                children: [
                  const CapBackButton(fallbackPath: AppPaths.clientProfile),
                  const Spacer(),
                  TextButton(
                    onPressed: _restoring ? null : _restore,
                    child: Text(_restoring ? 'Restoring…' : 'Restore'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
                children: [
                  Text(
                    '3 MONTHS FREEMIUM.\nTHEN YOU DECIDE.',
                    textAlign: TextAlign.center,
                    style: SwipessTokens.displayItalic(
                      color: ink,
                      fontSize: 33,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No confusing trial math. Your welcome window counts down for 3 months and gives you the full Premium feature experience.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (freemium)
                    _FreemiumStatus(
                      countdown: _countdown(subscription?.trialEndsAt),
                      balance: balance,
                    )
                  else if (paid)
                    _StatusCard(
                      title: 'PREMIUM ACTIVE',
                      subtitle: balance == null
                          ? 'Your paid Premium access is active.'
                          : '$balance Direct Requests available now.',
                      icon: Icons.verified_rounded,
                    )
                  else
                    _StatusCard(
                      title: 'FREE',
                      subtitle: 'Browsing, swiping, matched chat and your Virtual / Local ID stay free. AI, Legal, Events and Premium advantages require a plan after Freemium.',
                      icon: Icons.favorite_rounded,
                    ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Text(
                        'PREMIUM PACKAGES',
                        style: SwipessTokens.kickerUppercase(
                          color: ink.withAlpha(165),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '20 · 50 · 150',
                        style: GoogleFonts.plusJakartaSans(
                          color: muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final offer in IapCatalog.subscriptions) ...[
                    _PlanCard(
                      offer: offer,
                      buying: _buyingId == offer.id,
                      onBuy: () => _buy(offer),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 6),
                  _InfoCard(
                    title: 'WHAT STAYS FREE FOREVER',
                    text: 'Browse and swipe. Mutual matches and matched chat. Your Virtual / Local ID card. Direct Requests are separate credits you can earn or buy.',
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    title: 'WHEN THE 3 MONTHS END',
                    text: 'AI, AI Listing Creator, Legal, Events, Premium listing capacity/visibility and other Premium advantages lock until you choose a Premium package.',
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

class _FreemiumStatus extends StatelessWidget {
  const _FreemiumStatus({required this.countdown, required this.balance});

  final String countdown;
  final int? balance;

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
            const Color(0xFFEB4898).withAlpha(38),
            const Color(0xFF6366F1).withAlpha(24),
            MatteSurface.cardFill(context),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEB4898).withAlpha(95)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                label: 'FREEMIUM ACTIVE',
                background: const Color(0xFFEB4898),
                foreground: Colors.white,
              ),
              const Spacer(),
              const _Pill(
                label: 'FULL PREMIUM',
                background: Color(0x1822C55E),
                foreground: Color(0xFF22C55E),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            countdown,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'This countdown started with your 3-month Freemium window and keeps counting down automatically.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SAME FEATURE ACCESS AS YEARLY / UNLIMITED',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .65,
            ),
          ),
          const SizedBox(height: 10),
          const _Check('AI + AI Listing Creator'),
          const _Check('Legal Hub + Swipess Sign documents'),
          const _Check('Events discovery & access'),
          const _Check('Maximum listing capacity & Premium visibility'),
          const _Check('Priority matching / Premium advantages'),
          const SizedBox(height: 13),
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
                  '5 WELCOME DIRECT REQUESTS',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance == null
                      ? 'Freemium starts with 5. You can earn more through activity/referrals or buy more.'
                      : 'Current balance: $balance. The welcome grant is 5; a higher balance means extra Direct Requests were earned, referred, or purchased.',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 10.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Virtual / Local ID stays free even after Freemium ends.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

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
          Icon(icon, color: const Color(0xFFEB4898), size: 27),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 11,
                    height: 1.4,
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
    final yearly = offer.id.contains('1-year');
    final accent = yearly
        ? const Color(0xFFEB4898)
        : offer.popular
        ? const Color(0xFF6366F1)
        : ink;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: yearly || offer.popular
              ? accent.withAlpha(100)
              : MatteSurface.hairline(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            offer.name.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (yearly) ...[
                          const SizedBox(width: 8),
                          const _Pill(
                            label: 'UNLIMITED',
                            background: Color(0xFFEB4898),
                            foreground: Colors.white,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${offer.tokens ?? 0} DIRECT REQUESTS INCLUDED',
                      style: GoogleFonts.plusJakartaSans(
                        color: accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .55,
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
                      fontSize: 23,
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
          const SizedBox(height: 14),
          for (final benefit in offer.benefits) _Check(benefit),
          const SizedBox(height: 9),
          Text(
            'Matched chat stays free. Direct Requests are priority connection credits.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 9.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 47,
            child: FilledButton(
              onPressed: buying ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: yearly || offer.popular
                    ? Colors.white
                    : (MatteSurface.isLight(context)
                          ? Colors.white
                          : Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.text);
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
            child: Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(215),
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
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
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: .65,
      ),
    ),
  );
}
