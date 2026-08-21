import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_ui.dart';
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
  bool _busy = false;

  Color _colorForIndex(int index) {
    switch (index % 4) {
      case 0:
        return SwipessTokens.tierStarter;
      case 1:
        return SwipessTokens.tierPlus;
      case 2:
        return SwipessTokens.tierPower;
      default:
        return SwipessTokens.tierMega;
    }
  }

  Future<void> _buy(BuildContext context, IapOffer offer) async {
    if (_busy) return;
    setState(() => _busy = true);
    AppHaptics.light();
    final result = await ref.read(paymentServiceProvider).buy(offer);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(messagingEntitlementsProvider);
    ref.invalidate(directRequestBalanceProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
    if (result.isSuccess) {
      await AppHaptics.success();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(directRequestBalanceProvider);

    return Container(
      decoration: const BoxDecoration(
        color: SwipessTokens.darkCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
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
                style: SwipessTokens.displayItalic(fontSize: 27),
              ),
              const SizedBox(height: 5),
              balance.when(
                data: (b) => Text(
                  '${b.available} available${b.reserved > 0 ? ' · ${b.reserved} pending' : ''}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: SwipessTokens.brandOrange,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                loading: () => const SizedBox(
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, _) => const SizedBox(height: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Interest is free. Matches are free. Use a Direct Request when you want to skip the wait.',
                textAlign: TextAlign.center,
                style: SwipessTokens.bodyClean(
                  color: Colors.white60,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.replay_rounded,
                      color: SwipessTokens.brandOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Only spent when accepted. Declined, cancelled or expired requests return automatically.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  itemCount: IapCatalog.tokens.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final offer = IapCatalog.tokens[index];
                    final accent = _colorForIndex(index);
                    final count = offer.tokens ?? 0;
                    final badge = index == 1
                        ? 'POPULAR'
                        : index == IapCatalog.tokens.length - 1
                            ? 'BEST VALUE'
                            : null;
                    return SwipessTierCard(
                      accentColor: accent,
                      badgeLabel: badge,
                      isHighlighted: badge != null,
                      onTap: _busy ? null : () => _buy(context, offer),
                      child: Row(
                        children: [
                          SwipessIconTile(
                            icon: Icons.bolt_rounded,
                            accentColor: accent,
                            size: 46,
                            iconSize: 23,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$count DIRECT REQUESTS',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: .5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  offer.priceLabel,
                                  style: SwipessTokens.priceOversized(fontSize: 23),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  offer.description ?? '',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white45,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 76,
                            child: ElevatedButton(
                              onPressed: _busy ? null : () => _buy(context, offer),
                              child: const Text('GET'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  AppHaptics.medium();
                  Navigator.of(context).pop();
                  context.push(AppPaths.subscriptionPackages);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SwipessTokens.darkWell,
                    borderRadius: BorderRadius.circular(SwipessTokens.radiusTile),
                    border: Border.all(color: const Color(0xFFF59E0B).withAlpha(70)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Swipess often?',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Premium adds more priority, visibility, AI and scale.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                    ],
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final result = await ref
                              .read(paymentServiceProvider)
                              .restorePurchases();
                          if (!mounted) return;
                          ref.invalidate(messagingEntitlementsProvider);
                          ref.invalidate(directRequestBalanceProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result.userMessage)),
                          );
                        },
                  child: const Text('Restore Purchases'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
