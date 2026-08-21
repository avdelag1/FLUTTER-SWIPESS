import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_ui.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
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

  Future<void> _buy(IapOffer offer) async {
    if (_busy) return;
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
    if (_busy) return;
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

  Color _accentFor(int index, IapOffer offer) {
    if (offer.popular) return SwipessTokens.tierPlus;
    if (index == 0) return SwipessTokens.tierStarter;
    return SwipessTokens.tierPower;
  }

  String _audienceFor(int index) {
    switch (index) {
      case 0:
        return 'Travelers, short stays & active users';
      case 1:
        return 'Residents, nomads, workers & frequent users';
      default:
        return 'Owners, professionals, businesses & power users';
    }
  }

  String _promiseFor(int index) {
    switch (index) {
      case 0:
        return 'Full power while you’re here.';
      case 1:
        return 'For people who actually live here.';
      default:
        return 'Make Swipess work for you.';
    }
  }

  Widget _benefit(String text, Color accent, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: accent, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: isLight ? Colors.black87 : Colors.white.withAlpha(230),
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _freeCard(SubscriptionData data, bool isLight) {
    final ink = isLight ? Colors.black : Colors.white;
    final muted = isLight ? Colors.black54 : Colors.white60;
    final trial = data.isTrialActive;
    final accent = trial ? SwipessTokens.tierPower : Colors.grey;

    return SwipessTierCard(
      accentColor: accent,
      badgeLabel: trial ? 'ACTIVE NOW' : 'FREE',
      isHighlighted: trial,
      isLight: isLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trial ? 'YOUR WELCOME PREMIUM ACCESS' : 'SWIPESS FREE',
            style: SwipessTokens.kickerUppercase(color: accent, fontSize: 11),
          ),
          const SizedBox(height: 7),
          Text(
            trial ? 'Premium is active.' : 'Participate without paying.',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            trial
                ? 'Enjoy Premium advantages while your welcome access is active. Interest and matches stay free; Direct Requests stay finite priority actions.'
                : 'Swipe right to show interest for free. If they choose you too, chat opens free. Use a Direct Request only when you want to skip the wait.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in [
            'Unlimited free interest & discovery',
            'Mutual match = free chat',
            '1 active listing on Free',
            'Direct Requests use tokens only when accepted',
            if (trial) 'Premium AI, visibility & listing advantages during trial',
          ])
            _benefit(item, accent, isLight),
          if (trial && data.trialEndsAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Welcome access ends ${MaterialLocalizations.of(context).formatMediumDate(data.trialEndsAt!.toLocal())}. Purchased tokens remain yours.',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _economyExplainer(bool isLight) {
    final ink = isLight ? Colors.black : Colors.white;
    final muted = isLight ? Colors.black54 : Colors.white60;
    const accent = SwipessTokens.tierPlus;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ink.withAlpha(isLight ? 25 : 35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW SWIPESS WORKS',
            style: SwipessTokens.kickerUppercase(color: accent, fontSize: 10),
          ),
          const SizedBox(height: 12),
          _economyLine(Icons.favorite_rounded, 'Interested', 'FREE', ink, muted),
          _economyLine(Icons.handshake_rounded, 'Mutual match + chat', 'FREE', ink, muted),
          _economyLine(Icons.bolt_rounded, 'Direct Request', '1 TOKEN IF ACCEPTED', ink, muted),
          const SizedBox(height: 8),
          Text(
            'Premium doesn’t buy permission to contact people. It gives you more priority, visibility, AI and scale.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _economyLine(
    IconData icon,
    String title,
    String value,
    Color ink,
    Color muted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: SwipessTokens.tierPlus),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: value == 'FREE' ? muted : SwipessTokens.tierPlus,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: AmbientPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: ink),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy ? null : _restore,
                      child: const Text('Restore Purchases'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  children: [
                    Text(
                      'GET MORE FROM SWIPESS',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.displayItalic(color: ink, fontSize: 30),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'More speed. More visibility. More opportunities.',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.bodyClean(
                        color: ink.withAlpha(155),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _economyExplainer(isLight),
                    const SizedBox(height: 18),
                    subscription.when(
                      data: (data) => _freeCard(data, isLight),
                      loading: () => SwipessTierCard(
                        accentColor: SwipessTokens.tierPower,
                        isLight: isLight,
                        child: const SizedBox(
                          height: 86,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (_, _) => _freeCard(
                        SubscriptionData(tier: SubscriptionTier.free),
                        isLight,
                      ),
                    ),
                    const SizedBox(height: 26),
                    for (var i = 0; i < IapCatalog.subscriptions.length; i++) ...[
                      _PremiumPlanCard(
                        offer: IapCatalog.subscriptions[i],
                        accent: _accentFor(i, IapCatalog.subscriptions[i]),
                        audience: _audienceFor(i),
                        promise: _promiseFor(i),
                        isLight: isLight,
                        busy: _busy,
                        onBuy: () => _buy(IapCatalog.subscriptions[i]),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      'Not ready for Premium? No problem. Swipess still works for free. Buy tokens only when something matters enough to send a Direct Request.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(130),
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
      ),
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({
    required this.offer,
    required this.accent,
    required this.audience,
    required this.promise,
    required this.isLight,
    required this.busy,
    required this.onBuy,
  });

  final IapOffer offer;
  final Color accent;
  final String audience;
  final String promise;
  final bool isLight;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? Colors.black : Colors.white;
    final muted = isLight ? Colors.black54 : Colors.white60;
    return SwipessTierCard(
      accentColor: accent,
      badgeLabel: offer.label,
      isHighlighted: offer.popular,
      isLight: isLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.name.toUpperCase(),
            style: SwipessTokens.kickerUppercase(color: accent, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            promise,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 7,
            children: [
              Text(
                offer.priceLabel,
                style: SwipessTokens.priceOversized(color: ink, fontSize: 36),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  offer.durationLabel ?? '',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Best for: $audience',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
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
                        color: ink.withAlpha(220),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy ? null : onBuy,
              child: Text(
                busy
                    ? 'PROCESSING…'
                    : (offer.popular
                          ? 'GET LIVE LOCAL'
                          : 'CHOOSE ${offer.name.toUpperCase()}'),
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
