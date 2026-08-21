import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_ui.dart';
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
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _colorForIndex(int index) {
    switch (index % 4) {
      case 0:
        return SwipessTokens.tierStarter;
      case 1:
        return SwipessTokens.tierPlus;
      case 2:
        return SwipessTokens.tierPower;
      case 3:
      default:
        return SwipessTokens.tierMega;
    }
  }

  IconData _iconForIndex(int index) {
    switch (index % 4) {
      case 0:
        return Icons.bolt_outlined;
      case 1:
        return Icons.bolt_rounded;
      case 2:
        return Icons.workspace_premium_rounded;
      case 3:
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String? _badgeForIndex(int index, int total) {
    if (index == 1) return 'POPULAR';
    if (index == total - 1) return 'BEST VALUE';
    return null;
  }

  Future<void> _buyOffer(BuildContext context, IapOffer offer) async {
    AppHaptics.light();
    final result = await ref.read(paymentServiceProvider).buy(offer);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
    ref.invalidate(messagingEntitlementsProvider);
    if (result.isSuccess) {
      await AppHaptics.success();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Widget _offerInfo({
    required IapOffer offer,
    required Color color,
    required int count,
    required String pricePerRequest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              (offer.label ?? offer.name).toUpperCase(),
              style: SwipessTokens.displayItalic(
                color: color,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
              ),
              child: Text(
                '$count REQUESTS',
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              offer.priceLabel,
              style: SwipessTokens.priceOversized(fontSize: 22),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'USD',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (pricePerRequest.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  pricePerRequest,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(messagingEntitlementsProvider);
    final currentBalance = balanceAsync.value?.tokenBalance ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: SwipessTokens.darkCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'DIRECT REQUESTS',
                textAlign: TextAlign.center,
                style: SwipessTokens.displayItalic(fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                'You have $currentBalance ready to use',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: SwipessTokens.brandOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Interest is free and mutual matches chat for free. Use a Direct Request when you do not want to wait — it is only spent if the other person accepts.',
                textAlign: TextAlign.center,
                style: SwipessTokens.bodyClean(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  itemCount: IapCatalog.tokens.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final offer = IapCatalog.tokens[index];
                    final color = _colorForIndex(index);
                    final icon = _iconForIndex(index);
                    final badge = _badgeForIndex(index, IapCatalog.tokens.length);
                    final count = offer.tokens ?? 0;
                    final parsedPrice = double.tryParse(
                          offer.priceLabel.replaceAll(RegExp(r'[^0-9.]'), ''),
                        ) ??
                        0.0;
                    final pricePerRequest =
                        (count > 0 && parsedPrice > 0) ? (parsedPrice / count) : 0.0;
                    final pricePerRequestStr = pricePerRequest > 0
                        ? '\$${pricePerRequest.toStringAsFixed(2)}/request'
                        : '';

                    return SwipessTierCard(
                      accentColor: color,
                      isHighlighted: badge != null,
                      onTap: () => _buyOffer(context, offer),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 360;
                          final info = _offerInfo(
                            offer: offer,
                            color: color,
                            count: count,
                            pricePerRequest: pricePerRequestStr,
                          );

                          final mainRow = Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SwipessIconTile(
                                icon: icon,
                                accentColor: color,
                                size: compact ? 42 : 46,
                                iconSize: compact ? 20 : 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: info),
                              if (!compact) ...[
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 84,
                                  height: 38,
                                  child: SwipessPrimaryCTA(
                                    label: 'SELECT',
                                    accentColor: color,
                                    height: 38,
                                    onTap: () => _buyOffer(context, offer),
                                  ),
                                ),
                              ],
                            ],
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (badge != null) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SwipessTierBadge(
                                    label: badge,
                                    accentColor: color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              mainRow,
                              if (compact) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: SwipessPrimaryCTA(
                                    label: 'SELECT',
                                    accentColor: color,
                                    height: 40,
                                    onTap: () => _buyOffer(context, offer),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  AppHaptics.medium();
                  if (context.mounted) Navigator.of(context).pop();
                  context.push(AppPaths.subscriptionPackages);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: SwipessTokens.darkWell,
                    borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
                    border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withAlpha(20),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SwipessIconTile(
                        icon: Icons.workspace_premium_rounded,
                        accentColor: Color(0xFFF59E0B),
                        size: 38,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium includes priority',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Direct Requests + more visibility, AI and scale.',
                              style: SwipessTokens.bodyClean(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            AppHaptics.medium();
                            if (context.mounted) Navigator.of(context).pop();
                            context.push(AppPaths.subscriptionPackages);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            'SEE PLANS',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: .4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () async {
                    AppHaptics.light();
                    final result = await ref.read(paymentServiceProvider).restorePurchases();
                    if (!context.mounted) return;
                    ref.invalidate(messagingEntitlementsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.userMessage)),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(
                    'Restore Purchases',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
