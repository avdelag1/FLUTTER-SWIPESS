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

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);

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
                      'Compare the exact AI limits and member benefits included with each plan.',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.bodyClean(
                        color: ink.withAlpha(160),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    offer.priceLabel,
                                    style: SwipessTokens.priceOversized(
                                      color: isLight ? Colors.black : Colors.white,
                                      fontSize: 40,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (duration.isNotEmpty)
                                    Text(
                                      'USD / $duration',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isLight
                                            ? Colors.black54
                                            : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
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
                              for (final benefit in offer.benefits) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: accent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          benefit,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: isLight
                                                ? Colors.black87
                                                : Colors.white.withAlpha(230),
                                            fontWeight: benefit
                                                    .toLowerCase()
                                                    .contains('unlimited')
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                    SwipessTierCard(
                      accentColor: Colors.grey,
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
                          for (final f in const [
                            '1 Active Listing',
                            '30-day messaging trial for new accounts',
                            'Message Tokens can unlock new conversations',
                          ]) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: SwipessTokens.bodyClean(
                                        color: isLight
                                            ? Colors.black54
                                            : Colors.white60,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
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
