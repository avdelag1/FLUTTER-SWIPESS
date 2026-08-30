import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/providers/engagement_reward_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class TokensModal extends ConsumerStatefulWidget {
  const TokensModal({super.key});

  @override
  ConsumerState<TokensModal> createState() => _TokensModalState();
}

class _TokensModalState extends ConsumerState<TokensModal> {
  String? _buyingId;

  Future<void> _buy(IapOffer offer) async {
    if (_buyingId != null) return;
    setState(() => _buyingId = offer.id);
    AppHaptics.medium();
    final result = await ref.read(paymentServiceProvider).buy(offer);
    if (!mounted) return;
    setState(() => _buyingId = null);
    ref.invalidate(messagingEntitlementsProvider);
    ref.invalidate(directRequestBalanceProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.userMessage)));
    if (result.isSuccess) {
      await AppHaptics.success();
      await AppAudio.instance.playTokensFromPrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(directRequestBalanceProvider);
    final reward = ref.watch(engagementRewardProgressProvider);

    return Container(
      decoration: const BoxDecoration(
        color: SwipessTokens.darkCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  Text(
                    '⚡ DIRECT REQUESTS',
                    textAlign: TextAlign.center,
                    style: SwipessTokens.displayItalic(fontSize: 28),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Interest is free. Matches chat free. Use a token only when you want priority.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  balance.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (b) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withAlpha(25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _balance('AVAILABLE', '${b.available}'),
                          _balance('RESERVED', '${b.reserved}'),
                          _balance('TOTAL', '${b.total}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  reward.when(
                    loading: () => const _ActiveRewardStrip(steps: 0),
                    error: (_, _) => const _ActiveRewardStrip(steps: 0),
                    data: (p) => _ActiveRewardStrip(steps: p.steps),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: IapCatalog.tokens.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final offer = IapCatalog.tokens[index];
                  final count = offer.tokens ?? 0;
                  final popular = offer.popular;
                  return Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(popular ? 18 : 10),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: popular
                            ? SwipessTokens.tierPlus.withAlpha(110)
                            : Colors.white.withAlpha(25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '$count DIRECT REQUESTS',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (popular) ...[
                                    const SizedBox(width: 7),
                                    Text(
                                      'POPULAR',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: SwipessTokens.tierPlus,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Only spent when your request is accepted.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              offer.priceLabel,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            SizedBox(
                              height: 34,
                              child: FilledButton(
                                onPressed: _buyingId == null
                                    ? () => _buy(offer)
                                    : null,
                                child: _buyingId == offer.id
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('GET'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '↩ Declined, cancelled before acceptance, or unanswered? Your reserved token returns automatically.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(AppPaths.subscriptionPackages);
                    },
                    child: const Text('Use Swipess often? See Premium →'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balance(String label, String value) => Column(
    children: [
      Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .7,
        ),
      ),
    ],
  );
}

class _ActiveRewardStrip extends StatelessWidget {
  const _ActiveRewardStrip({required this.steps});

  final int steps;

  @override
  Widget build(BuildContext context) {
    final completed = steps.clamp(0, 5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withAlpha(15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF60A5FA).withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFF93C5FD),
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'EARN FREE TOKENS WHILE YOU USE SWIPESS',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              ),
              Text(
                '$completed/5',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF93C5FD),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i <= completed
                            ? const Color(0xFF60A5FA)
                            : Colors.white.withAlpha(22),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                Container(
                  width: i == 5 ? 28 : 23,
                  height: i == 5 ? 28 : 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= completed
                        ? (i == 5
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF2563EB))
                        : Colors.white.withAlpha(13),
                    border: Border.all(color: Colors.white.withAlpha(28)),
                  ),
                  alignment: Alignment.center,
                  child: i == 5
                      ? Icon(
                          Icons.card_giftcard_rounded,
                          size: 13,
                          color: i <= completed
                              ? Colors.white
                              : Colors.white38,
                        )
                      : i <= completed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            )
                          : Text(
                              '$i',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            completed == 4
                ? 'Your next reward is close. Keep exploring.'
                : 'Complete all 5 steps and your free token is added automatically.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
