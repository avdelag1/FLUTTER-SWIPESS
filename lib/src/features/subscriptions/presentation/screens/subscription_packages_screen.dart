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
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionPackagesScreen extends ConsumerStatefulWidget {
  const SubscriptionPackagesScreen({super.key});
  @override
  ConsumerState<SubscriptionPackagesScreen> createState() => _SubscriptionPackagesScreenState();
}

class _SubscriptionPackagesScreenState extends ConsumerState<SubscriptionPackagesScreen> {
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
      await AppHaptics.success();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentResultScreen(success: true)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.userMessage)));
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref.read(paymentServiceProvider).restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(messagingEntitlementsProvider);
    ref.invalidate(subscriptionProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.userMessage)));
  }

  Color _accent(int index, IapOffer offer) {
    if (offer.popular) return SwipessTokens.tierPlus;
    return index == 0 ? SwipessTokens.tierStarter : SwipessTokens.tierPower;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);
    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: AmbientPageBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 0),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_ios_new_rounded, color: ink)),
                const Spacer(),
                TextButton(onPressed: _busy ? null : _restore, child: Text('Restore Purchases', style: TextStyle(color: ink.withAlpha(150)))),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  Text('GET MORE FROM SWIPESS', textAlign: TextAlign.center, style: SwipessTokens.displayItalic(color: ink, fontSize: 30)),
                  const SizedBox(height: 7),
                  Text('More speed. More visibility. More opportunities.', textAlign: TextAlign.center, style: SwipessTokens.bodyClean(color: ink.withAlpha(155), fontSize: 14)),
                  const SizedBox(height: 20),
                  _HowItWorks(isLight: isLight),
                  const SizedBox(height: 18),
                  _CurrentAccess(isLight: isLight),
                  const SizedBox(height: 4),
                  for (var i = 0; i < IapCatalog.subscriptions.length; i++) ...[
                    _PlanCard(offer: IapCatalog.subscriptions[i], accent: _accent(i, IapCatalog.subscriptions[i]), isLight: isLight, busy: _busy, onBuy: () => _buy(IapCatalog.subscriptions[i])),
                    const SizedBox(height: 16),
                  ],
                  Text('Not ready for Premium? Keep using Swipess for free and buy Direct Requests only when something matters enough to skip the wait.', textAlign: TextAlign.center, style: SwipessTokens.bodyClean(color: ink.withAlpha(135), fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.isLight});
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ink.withAlpha(isLight ? 8 : 12), borderRadius: BorderRadius.circular(22), border: Border.all(color: ink.withAlpha(25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SWIPESS WORKS FOR FREE', style: SwipessTokens.kickerUppercase(color: ink.withAlpha(140), fontSize: 10)),
        const SizedBox(height: 11),
        _rule(Icons.favorite_rounded, 'Interest is free', ink),
        _rule(Icons.handshake_rounded, 'Mutual match = free chat', ink),
        _rule(Icons.bolt_rounded, 'Direct Request = priority', ink),
        const SizedBox(height: 8),
        Text('Premium never buys access to people. It gives you more speed, visibility, AI and scale.', style: SwipessTokens.bodyClean(color: ink.withAlpha(145), fontSize: 12.5)),
      ]),
    );
  }

  Widget _rule(IconData icon, String text, Color ink) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Icon(icon, color: SwipessTokens.brandOrange, size: 18),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(color: ink, fontSize: 13, fontWeight: FontWeight.w800))),
    ]),
  );
}

class _CurrentAccess extends ConsumerWidget {
  const _CurrentAccess({required this.isLight});
  final bool isLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final free = data.tier == SubscriptionTier.free;
        final trial = data.isTrialActive && data.trialEndsAt != null;
        final accent = trial || !free ? SwipessTokens.tierPower : Colors.grey;
        final title = trial ? 'WELCOME PREMIUM ACTIVE' : free ? 'CURRENT PLAN — FREE' : 'PREMIUM ACTIVE';
        final body = trial
            ? 'Your welcome Premium access is active. Experience the faster marketplace before choosing a plan.'
            : free
                ? 'Browse, show interest and chat after a mutual match for free. Use Direct Requests only when you want priority.'
                : 'Your included Direct Requests follow the same fair rule: they are spent only when accepted.';
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: SwipessTierCard(
            accentColor: accent,
            isHighlighted: trial || !free,
            isLight: isLight,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: SwipessTokens.kickerUppercase(color: accent, fontSize: 11)),
              const SizedBox(height: 7),
              Text(body, style: SwipessTokens.bodyClean(color: isLight ? Colors.black54 : Colors.white60, fontSize: 13)),
            ]),
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.offer, required this.accent, required this.isLight, required this.busy, required this.onBuy});
  final IapOffer offer;
  final Color accent;
  final bool isLight;
  final bool busy;
  final VoidCallback onBuy;

  String get _promise {
    if (offer.id.contains('1-month')) return 'Full power while you’re here.';
    if (offer.id.contains('6-months')) return 'For people who actually live here.';
    return 'Make Swipess work for you.';
  }

  String get _audience {
    if (offer.id.contains('1-month')) return 'Travelers and active short-term users.';
    if (offer.id.contains('6-months')) return 'Residents, nomads, workers and frequent users.';
    return 'Owners, professionals, businesses and power users.';
  }

  @override
  Widget build(BuildContext context) {
    return SwipessTierCard(
      accentColor: accent,
      badgeLabel: offer.label,
      isHighlighted: offer.popular,
      isLight: isLight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(offer.name.toUpperCase(), style: SwipessTokens.kickerUppercase(color: accent, fontSize: 12)),
        const SizedBox(height: 7),
        Text(_promise, style: SwipessTokens.displayItalic(color: isLight ? Colors.black : Colors.white, fontSize: 20)),
        const SizedBox(height: 9),
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
          Text(offer.priceLabel, style: SwipessTokens.priceOversized(color: isLight ? Colors.black : Colors.white, fontSize: 36)),
          Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(offer.durationLabel ?? '', style: TextStyle(color: isLight ? Colors.black45 : Colors.white54))),
        ]),
        Text(_audience, style: SwipessTokens.bodyClean(color: isLight ? Colors.black54 : Colors.white60, fontSize: 12)),
        const SizedBox(height: 15),
        for (final benefit in offer.benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_rounded, color: accent, size: 17),
              const SizedBox(width: 9),
              Expanded(child: Text(benefit, style: GoogleFonts.plusJakartaSans(color: isLight ? Colors.black87 : Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: busy ? null : onBuy,
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, shape: const StadiumBorder(), elevation: 0),
            child: Text(busy ? 'PROCESSING…' : 'CHOOSE ${offer.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 9),
        Text('Included Direct Requests are only spent when the other person accepts.', textAlign: TextAlign.center, style: SwipessTokens.bodyClean(color: isLight ? Colors.black38 : Colors.white38, fontSize: 10.5)),
      ]),
    );
  }
}
