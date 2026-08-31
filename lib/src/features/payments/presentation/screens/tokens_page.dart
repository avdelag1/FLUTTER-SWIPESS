import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/providers/engagement_reward_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showTokensPage(BuildContext context) {
  AppHaptics.medium();
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const TokensPage(),
    ),
  );
}

/// Opaque, fixed-layout purchase surface used for Direct Request token packs.
///
/// This intentionally does not use the glass modal system. The app behind the
/// purchase surface must never show through, and the complete catalog must fit
/// on one phone screen without vertical scrolling.
class TokensPage extends ConsumerStatefulWidget {
  const TokensPage({super.key});

  @override
  ConsumerState<TokensPage> createState() => _TokensPageState();
}

class _TokensPageState extends ConsumerState<TokensPage> {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );

    if (result.isSuccess) {
      await AppHaptics.success();
      await AppAudio.instance.playTokensFromPrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(directRequestBalanceProvider);
    final reward = ref.watch(engagementRewardProgressProvider);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: SwipessTokens.darkCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700 || constraints.maxWidth < 365;
            final gap = compact ? 7.0 : 10.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                compact ? 8 : 12,
                compact ? 12 : 16,
                media.padding.bottom > 0 ? 4 : 10,
              ),
              child: Column(
                children: [
                  _Header(compact: compact),
                  SizedBox(height: gap),
                  Text(
                    'Priority contact without waiting for a match.',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFC7C7D0),
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w650,
                    ),
                  ),
                  SizedBox(height: gap),
                  _BalanceStrip(balance: balance, compact: compact),
                  SizedBox(height: gap),
                  _RewardStrip(reward: reward, compact: compact),
                  SizedBox(height: gap),
                  Expanded(
                    child: _PackageGrid(
                      compact: compact,
                      buyingId: _buyingId,
                      onBuy: _buy,
                    ),
                  ),
                  SizedBox(height: gap),
                  Text(
                    'Declined, cancelled before acceptance, or unanswered? The reserved token returns automatically.',
                    textAlign: TextAlign.center,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF9898A5),
                      fontSize: compact ? 9.2 : 10.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 42 : 48,
      child: Row(
        children: [
          _RoundButton(
            tooltip: 'Close',
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIRECT REQUESTS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwipessTokens.displayItalic(fontSize: compact ? 21 : 25),
                ),
                Text(
                  'TOKEN PACKS · NATIVE PURCHASE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: compact ? 8 : 9,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: compact ? 34 : 38,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF34343E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFFFC247), size: 17),
                const SizedBox(width: 4),
                Text(
                  '1 = 1 request',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w800,
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

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip({required this.balance, required this.compact});

  final AsyncValue<DirectRequestBalance> balance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 50 : 58,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161C),
        borderRadius: BorderRadius.circular(compact ? 16 : 19),
        border: Border.all(color: const Color(0xFF2C2C35)),
      ),
      child: balance.when(
        loading: () => const Center(child: LinearProgressIndicator(minHeight: 2)),
        error: (_, _) => const Center(
          child: Text('Balance unavailable', style: TextStyle(color: Colors.white70)),
        ),
        data: (b) => Row(
          children: [
            Expanded(child: _BalanceValue(label: 'AVAILABLE', value: '${b.available}', compact: compact)),
            const _Divider(),
            Expanded(child: _BalanceValue(label: 'RESERVED', value: '${b.reserved}', compact: compact)),
            const _Divider(),
            Expanded(child: _BalanceValue(label: 'TOTAL', value: '${b.total}', compact: compact)),
          ],
        ),
      ),
    );
  }
}

class _BalanceValue extends StatelessWidget {
  const _BalanceValue({required this.label, required this.value, required this.compact});

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: compact ? 17 : 20,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF9898A5),
            fontSize: compact ? 7.6 : 8.5,
            letterSpacing: .55,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: const Color(0xFF34343E),
      );
}

class _RewardStrip extends StatelessWidget {
  const _RewardStrip({required this.reward, required this.compact});

  final AsyncValue<dynamic> reward;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final steps = reward.maybeWhen(
      data: (value) => ((value.steps as num?)?.toInt() ?? 0).clamp(0, 5),
      orElse: () => 0,
    );

    return Container(
      height: compact ? 39 : 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF271624), Color(0xFF241817)],
        ),
        borderRadius: BorderRadius.circular(compact ? 14 : 17),
        border: Border.all(color: const Color(0xFF5A2943)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF6B35), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'CONSISTENCY CHALLENGE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: compact ? 9 : 10,
                letterSpacing: .45,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (var i = 1; i <= 5; i++) ...[
            Container(
              width: compact ? 17 : 20,
              height: compact ? 17 : 20,
              margin: const EdgeInsets.only(left: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i <= steps ? const Color(0xFFFF4458) : const Color(0xFF3A2A31),
                shape: BoxShape.circle,
              ),
              child: i <= steps
                  ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                  : Text(
                      '$i',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageGrid extends StatelessWidget {
  const _PackageGrid({
    required this.compact,
    required this.buyingId,
    required this.onBuy,
  });

  final bool compact;
  final String? buyingId;
  final ValueChanged<IapOffer> onBuy;

  @override
  Widget build(BuildContext context) {
    final offers = IapCatalog.tokens;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _PackageCard(offer: offers[0], compact: compact, buyingId: buyingId, onBuy: onBuy)),
              const SizedBox(width: 8),
              Expanded(child: _PackageCard(offer: offers[1], compact: compact, buyingId: buyingId, onBuy: onBuy)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _PackageCard(offer: offers[2], compact: compact, buyingId: buyingId, onBuy: onBuy)),
              const SizedBox(width: 8),
              Expanded(child: _PackageCard(offer: offers[3], compact: compact, buyingId: buyingId, onBuy: onBuy)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.offer,
    required this.compact,
    required this.buyingId,
    required this.onBuy,
  });

  final IapOffer offer;
  final bool compact;
  final String? buyingId;
  final ValueChanged<IapOffer> onBuy;

  @override
  Widget build(BuildContext context) {
    final count = offer.tokens ?? 0;
    final busy = buyingId == offer.id;
    final disabled = buyingId != null && !busy;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 13),
      decoration: BoxDecoration(
        color: offer.popular ? const Color(0xFF201A25) : const Color(0xFF16161C),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(
          color: offer.popular ? const Color(0xFF8B4A72) : const Color(0xFF2C2C35),
          width: offer.popular ? 1.4 : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = constraints.maxHeight < 130;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: dense ? 28 : 34,
                    height: dense ? 28 : 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25252D),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFFFFC247), size: 19),
                  ),
                  const Spacer(),
                  if (offer.popular)
                    Text(
                      'POPULAR',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.brandPrimary,
                        fontSize: dense ? 7 : 8,
                        letterSpacing: .55,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              SizedBox(height: dense ? 5 : 8),
              Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: dense ? 22 : 27,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'DIRECT REQUESTS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFC7C7D0),
                  fontSize: dense ? 8 : 9,
                  letterSpacing: .35,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      offer.priceLabel,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: dense ? 15 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: dense ? 31 : 35,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2D6F), Color(0xFFFF4458)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x553D0C22),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: disabled ? null : () => onBuy(offer),
                        style: FilledButton.styleFrom(
                          minimumSize: Size(dense ? 54 : 62, 0),
                          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 13),
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'GET',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: dense ? 9 : 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.tooltip, required this.onTap, required this.child});

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF1B1B22),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}
