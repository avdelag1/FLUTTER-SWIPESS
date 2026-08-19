import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_ui.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/payment_result_screen.dart';
import 'package:flutter_swipes/src/features/subscriptions/data/subscription_repository.dart';
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
  bool _busy = false;
  final _scrollController = ScrollController();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // This timer only lives while the premium page is open. It refreshes the
    // visible trial clock without touching dashboard/video state.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _buy(IapOffer offer) async {
    setState(() => _busy = true);
    AppHaptics.medium();
    final result = await ref.read(paymentServiceProvider).buy(offer);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(messagingEntitlementsProvider);
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
    setState(() => _busy = true);
    final result = await ref.read(paymentServiceProvider).restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(messagingEntitlementsProvider);
    ref.invalidate(subscriptionProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
  }

  Color _accentForOffer(IapOffer offer, int index) {
    if (offer.popular) return SwipessTokens.tierPlus;
    if (index == 0) return SwipessTokens.tierStarter;
    return SwipessTokens.tierPower;
  }

  String _badgeForOffer(IapOffer offer, int index, int total) {
    final catalogLabel = offer.label?.trim();
    if (catalogLabel != null && catalogLabel.isNotEmpty) {
      return catalogLabel.toUpperCase();
    }
    if (offer.popular) return 'POPULAR';
    if (index == total - 1) return 'BEST VALUE';
    return 'STARTER';
  }

  String _durationText(String? raw) {
    return (raw ?? '')
        .trim()
        .replaceFirst(RegExp(r'^/\s*'), '')
        .trim()
        .toUpperCase();
  }

  String _threeMonthValue() {
    final monthly = IapCatalog.subscriptions.first;
    final price = double.tryParse(
          monthly.priceLabel.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;
    return price <= 0 ? monthly.priceLabel : '\$${(price * 3).toStringAsFixed(2)}';
  }

  String _trialCountdown(DateTime end) {
    final remaining = end.toUtc().difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return '00d  00h  00m  00s';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(days)}d  ${two(hours)}h  ${two(minutes)}m  ${two(seconds)}s';
  }

  String _trialEndLabel(DateTime end) {
    final local = end.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}  ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _benefitRow({
    required String text,
    required Color accent,
    required bool isLight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle_rounded, color: accent, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: isLight ? Colors.black87 : Colors.white.withAlpha(230),
                fontSize: 13.5,
                height: 1.25,
                fontWeight: text.toLowerCase().contains('unlimited')
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentAccessCard(
    SubscriptionData data, {
    required bool isLight,
  }) {
    if (data.tier != SubscriptionTier.free) {
      return const SizedBox.shrink();
    }

    if (data.isTrialActive && data.trialEndsAt != null) {
      final end = data.trialEndsAt!;
      const accent = SwipessTokens.tierPower;
      const benefits = <String>[
        'AI Concierge — Unlimited during your trial',
        'AI Listing Creator — Unlimited during your trial',
        'Communicate with listings and members',
        'Post properties, services & motos with Premium limits',
        'Events access included',
        'Legal services access included',
        'Virtual ID card access included',
        'Premium messaging access — no message token required while active',
      ];

      return SwipessTierCard(
        accentColor: accent,
        badgeLabel: 'ACTIVE NOW',
        isHighlighted: true,
        isLight: isLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR 3-MONTH PREMIUM WELCOME ACCESS',
              style: SwipessTokens.kickerUppercase(
                color: accent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'FREE',
                  style: SwipessTokens.priceOversized(
                    color: isLight ? Colors.black : Colors.white,
                    fontSize: 36,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '3-month value ${_threeMonthValue()} USD',
                    style: GoogleFonts.plusJakartaSans(
                      color: isLight ? Colors.black54 : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'You already have Premium access. No purchase is needed while this countdown is active.',
              style: SwipessTokens.bodyClean(
                color: isLight ? Colors.black54 : Colors.white60,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: accent.withAlpha(isLight ? 18 : 28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PREMIUM TIME REMAINING',
                    style: SwipessTokens.kickerUppercase(
                      color: accent,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _trialCountdown(end),
                      style: GoogleFonts.plusJakartaSans(
                        color: isLight ? Colors.black : Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ends ${_trialEndLabel(end)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: isLight ? Colors.black45 : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'INCLUDED RIGHT NOW',
              style: SwipessTokens.kickerUppercase(
                color: isLight ? Colors.black54 : Colors.white60,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 10),
            for (final benefit in benefits)
              _benefitRow(text: benefit, accent: accent, isLight: isLight),
            const SizedBox(height: 4),
            Text(
              'When the countdown reaches zero, your account returns to Free access unless you choose a Premium plan. Purchased message tokens remain available for new conversations.',
              style: SwipessTokens.bodyClean(
                color: isLight ? Colors.black45 : Colors.white54,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
    }

    const accent = Colors.grey;
    return SwipessTierCard(
      accentColor: accent,
      isLight: isLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT FREE ACCESS',
            style: SwipessTokens.kickerUppercase(
              color: isLight ? Colors.black54 : Colors.white60,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'FREE',
            style: SwipessTokens.priceOversized(
              color: isLight ? Colors.black : Colors.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          for (final feature in const [
            '1 Active Listing',
            'Message Tokens can unlock new conversations',
            'Upgrade to restore Premium AI, Events, Legal and member benefits',
          ])
            _benefitRow(text: feature, accent: accent, isLight: isLight),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);
    final subscriptionAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: AmbientPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ink.withAlpha(isLight ? 15 : 25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ink.withAlpha(isLight ? 30 : 60),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: ink,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy ? null : _restore,
                      child: Text(
                        'Restore Purchases',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink.withAlpha(160),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    Text(
                      'PREMIUM PLANS',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.displayItalic(
                        color: ink,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'See what you have now, when it changes, and what each Premium plan includes.',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.bodyClean(
                        color: ink.withAlpha(160),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    subscriptionAsync.when(
                      data: (data) => _currentAccessCard(
                        data,
                        isLight: isLight,
                      ),
                      loading: () => SwipessTierCard(
                        accentColor: SwipessTokens.tierPower,
                        isLight: isLight,
                        child: const SizedBox(
                          height: 72,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (_, _) => _currentAccessCard(
                        SubscriptionData(tier: SubscriptionTier.free),
                        isLight: isLight,
                      ),
                    ),
                    const SizedBox(height: 30),
                    for (var i = 0; i < IapCatalog.subscriptions.length; i++) ...[
                      () {
                        final offer = IapCatalog.subscriptions[i];
                        final accent = _accentForOffer(offer, i);
                        final badge = _badgeForOffer(
                          offer,
                          i,
                          IapCatalog.subscriptions.length,
                        );
                        final duration = _durationText(offer.durationLabel);

                        return SwipessTierCard(
                          accentColor: accent,
                          badgeLabel: badge,
                          isHighlighted: offer.popular,
                          isLight: isLight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.name.toUpperCase(),
                                style: SwipessTokens.kickerUppercase(
                                  color: accent,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.end,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    offer.priceLabel,
                                    style: SwipessTokens.priceOversized(
                                      color: isLight ? Colors.black : Colors.white,
                                      fontSize: 40,
                                    ),
                                  ),
                                  if (duration.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Text(
                                        'USD / $duration',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isLight
                                              ? Colors.black54
                                              : Colors.white54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(
                                color: isLight
                                    ? Colors.black.withAlpha(15)
                                    : Colors.white.withAlpha(20),
                                height: 1,
                              ),
                              const SizedBox(height: 16),
                              for (final benefit in offer.benefits)
                                _benefitRow(
                                  text: benefit,
                                  accent: accent,
                                  isLight: isLight,
                                ),
                              const SizedBox(height: 20),
                              SwipessPrimaryCTA(
                                label: 'CHOOSE PLAN',
                                accentColor: accent,
                                isLoading: _busy,
                                onTap: _busy ? null : () => _buy(offer),
                              ),
                            ],
                          ),
                        );
                      }(),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
