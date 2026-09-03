import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/payment_result_screen.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_countdown.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionPackagesScreen extends ConsumerStatefulWidget {
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
      await AppAudio.instance.playTokensFromPrefs();
      if (!mounted) return;
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

  String _countdown(DateTime? endsAt) =>
      subscriptionCountdownParts(endsAt).compactLabel;

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
              padding: EdgeInsets.fromLTRB(10, 5, 10, 0),
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
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.sizeOf(context).width >= 700 ? 34 : 12,
                  20,
                  44,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '3 MONTHS FREEMIUM.\nTHEN YOU DECIDE.',
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
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No confusing trial math. Your welcome window counts down for 3 months and previews AI, Legal, Events and core Premium features. Listing video promotion unlocks only with a paid Premium package.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20),
                  if (freemium)
                    _FreemiumStatus(
                      countdown: _countdown(subscription?.trialEndsAt),
                      balance: balance,
                    )
                  else if (paid)
                    _PaidStatus(
                      countdown: _countdown(subscription.subscriptionEndsAt),
                      label: subscription.membershipCountdownLabel,
                      balance: balance,
                    )
                  else
                    _StatusCard(
                      title: 'FREE',
                      subtitle: 'Browsing, swiping, matched chat and your Virtual / Local ID stay free. AI, Legal, Events and Premium advantages require a plan after Freemium.',
                      icon: Icons.favorite_rounded,
                    ),
                  SizedBox(height: 26),
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
                  SizedBox(height: 12),
                  if (widget.launchOfferActive) ...[
                    _LaunchCampaignBanner(
                      foundingSize: widget.launchFoundingSize,
                      spotCap: widget.launchBuyerCap,
                      claimedSpots: widget.launchClaimed,
                    ),
                    SizedBox(height: 14),
                  ],
                  for (final offer in IapCatalog.subscriptions) ...[
                    _PlanCard(
                      offer: offer,
                      buying: _buyingId == offer.id,
                      onBuy: () => _buy(offer),
                      launchOfferActive: widget.launchOfferActive,
                      launchFoundingSize: widget.launchFoundingSize,
                      launchBuyerCap: widget.launchBuyerCap,
                      launchClaimed: widget.launchClaimed,
                    ),
                    SizedBox(height: 14),
                  ],
                  SizedBox(height: 6),
                  _DiscoveryBoostSection(),
                  SizedBox(height: 6),
                  _InfoCard(
                    title: 'PAID PREMIUM VIDEO BOOST',
                    text: 'Paid Premium members can upload one high-quality portrait 9:16 video per listing. Video listings are eligible to play directly inside their matching dashboard Quick Filter for extra exposure.',
                  ),
                  SizedBox(height: 10),
                  _InfoCard(
                    title: 'WHAT STAYS FREE FOREVER',
                    text: 'Browse and swipe. Mutual matches and matched chat. Your Virtual / Local ID card. Direct Requests are separate credits you can earn or buy.',
                  ),
                  SizedBox(height: 10),
                  _InfoCard(
                    title: 'WHEN THE 3 MONTHS END',
                    text: 'AI, AI Listing Creator, Legal, Events, Premium listing capacity/visibility and other Premium advantages lock until you choose a Premium package. Listing video upload and dashboard Quick Filter video exposure always require a paid package.',
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
      padding: EdgeInsets.all(18),
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
                label: 'PREMIUM PREVIEW',
                background: Color(0x1822C55E),
                foreground: Color(0xFF22C55E),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            countdown,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'This countdown started with your 3-month Freemium window and keeps counting down automatically.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'FREEMIUM FEATURE ACCESS',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .65,
            ),
          ),
          SizedBox(height: 10),
          const _Check('AI + AI Listing Creator'),
          const _Check('Legal Hub + Swipess Sign documents'),
          const _Check('Events discovery & access'),
          const _Check('Maximum listing capacity & Premium visibility'),
          const _Check('Priority matching / Premium advantages'),
          SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(13),
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
                SizedBox(height: 4),
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
          SizedBox(height: 10),
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

class _PaidStatus extends StatelessWidget {
  const _PaidStatus({
    required this.countdown,
    required this.label,
    required this.balance,
  });

  final String countdown;
  final String label;
  final int? balance;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF22C55E).withAlpha(38),
            const Color(0xFF6366F1).withAlpha(24),
            MatteSurface.cardFill(context),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF22C55E).withAlpha(95)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                label: label,
                background: const Color(0xFF22C55E),
                foreground: Colors.white,
              ),
              const Spacer(),
              const _Pill(
                label: 'PREMIUM ACTIVE',
                background: Color(0x1822C55E),
                foreground: Color(0xFF22C55E),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            countdown,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Live countdown until your current package renews or ends.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (balance != null) ...[
            SizedBox(height: 16),
            Text(
              '$balance Direct Requests available now.',
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFEB4898), size: 27),
          SizedBox(width: 12),
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
                SizedBox(height: 4),
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

class _LaunchCampaignBanner extends StatelessWidget {
  const _LaunchCampaignBanner({
    required this.foundingSize,
    required this.spotCap,
    required this.claimedSpots,
  });

  final int foundingSize;
  final int spotCap;
  final int claimedSpots;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final safe = claimedSpots.clamp(0, spotCap).toInt();
    final left = (spotCap - safe).clamp(0, spotCap).toInt();
    final progress = spotCap <= 0 ? 0.0 : safe / spotCap;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFEB4898).withAlpha(48),
          const Color(0xFFFFB800).withAlpha(28),
          MatteSurface.cardFill(context),
        ]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEB4898).withAlpha(130)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 7, runSpacing: 7, children: [
          _Pill(label: 'LIMITED 2×1 PREMIUM', background: const Color(0xFFEB4898), foreground: Colors.white),
          _Pill(label: 'FOUNDING $foundingSize', background: const Color(0xFFFFB800), foreground: Colors.black),
        ]),
        SizedBox(height: 12),
        Text('$left OF $spotCap PROMO SPOTS LEFT', style: GoogleFonts.plusJakartaSans(color: ink, fontSize: 17, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: ink.withAlpha(12), valueColor: const AlwaysStoppedAnimation(Color(0xFFEB4898)))),
        SizedBox(height: 9),
        Text('Every verified buyer claims 2 spots. Pay for one Premium period and receive double the time.', style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 10.5, height: 1.4, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
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
      padding: EdgeInsets.all(18),
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
                          SizedBox(width: 8),
                          const _Pill(
                            label: 'UNLIMITED',
                            background: Color(0xFFEB4898),
                            foreground: Colors.white,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3),
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
          if (launchOfferActive && launchBuyerCap > 0) ...[
            SizedBox(height: 12),
            _LaunchOfferStrip(
              offer: offer,
              foundingSize: launchFoundingSize,
              buyerCap: launchBuyerCap,
              claimed: launchClaimed,
            ),
          ],
          SizedBox(height: 14),
          for (final benefit in offer.benefits) _Check(benefit),
          SizedBox(height: 9),
          Text(
            'Matched chat stays free. Direct Requests are priority connection credits.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 9.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 13),
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
                  ? SizedBox(
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
      padding: EdgeInsets.fromLTRB(12, 11, 12, 12),
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
                label: '$remaining OF $buyerCap PROMO SPOTS LEFT',
                background: ink.withAlpha(12),
                foreground: ink,
              ),
            ],
          ),
          SizedBox(height: 9),
          Text(
            'LIMITED 2-FOR-1 · $_doubleTimeLabel',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Every verified Premium buyer claims 2 promo spots and receives 2× the Premium duration. $safeClaimed/$buyerCap spots claimed.',
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: EdgeInsets.all(15),
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
          SizedBox(height: 5),
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
      padding: EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: Color(0xFF22C55E),
            ),
          ),
          SizedBox(width: 8),
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

class _DiscoveryBoostSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    const rows = <(String, String)>[
      (
        'HERE NOW',
        'AI discoverability — get found when people search mechanics, massage, prices & more',
      ),
      (
        'LIVE LOCAL',
        '2× profile views in feeds, map & search + 90-day Profile Insights CRM',
      ),
      (
        'PRO',
        'First in AI & local results + 1-year insights history with export',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEB4898).withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISCOVERY & INSIGHTS BY PLAN',
            style: GoogleFonts.plusJakartaSans(
              color: ink.withAlpha(165),
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 10),
          for (final row in rows) ...[
            Text(
              row.$1,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 3),
            Text(
              row.$2,
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (row != rows.last) SizedBox(height: 12),
          ],
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
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
