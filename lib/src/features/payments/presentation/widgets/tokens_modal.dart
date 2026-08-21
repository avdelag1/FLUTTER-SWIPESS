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
  String? _cancellingId;

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
    ref.invalidate(pendingDirectRequestsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
    if (result.isSuccess) {
      await AppHaptics.success();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _cancelPending(String requestId) async {
    if (_cancellingId != null) return;
    setState(() => _cancellingId = requestId);
    try {
      final result = await ref
          .read(directRequestRepositoryProvider)
          .cancel(requestId);
      if (!mounted) return;
      ref.invalidate(directRequestBalanceProvider);
      ref.invalidate(pendingDirectRequestsProvider);
      ref.invalidate(messagingEntitlementsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.tokenReturned
                ? 'Direct Request cancelled. Your token is available again.'
                : 'Direct Request updated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel request: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(directRequestBalanceProvider);
    final pending = ref.watch(pendingDirectRequestsProvider);

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
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  children: [
                    pending.when(
                      data: (requests) {
                        if (requests.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'PENDING',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final request in requests) ...[
                              _PendingRequestTile(
                                request: request,
                                cancelling:
                                    _cancellingId == request['id']?.toString(),
                                onCancel: () => _cancelPending(
                                  request['id'].toString(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    Text(
                      'GET MORE',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var index = 0;
                        index < IapCatalog.tokens.length;
                        index++) ...[
                      _TokenOfferCard(
                        offer: IapCatalog.tokens[index],
                        accent: _colorForIndex(index),
                        badge: index == 1
                            ? 'POPULAR'
                            : index == IapCatalog.tokens.length - 1
                                ? 'BEST VALUE'
                                : null,
                        busy: _busy,
                        onBuy: () => _buy(context, IapCatalog.tokens[index]),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
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
                    borderRadius:
                        BorderRadius.circular(SwipessTokens.radiusTile),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withAlpha(70),
                    ),
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
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white54,
                      ),
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
                          ref.invalidate(pendingDirectRequestsProvider);
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

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.request,
    required this.cancelling,
    required this.onCancel,
  });

  final Map<String, dynamic> request;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final message = (request['message']?.toString() ?? '').trim();
    final expiresAt = DateTime.tryParse(
      request['expires_at']?.toString() ?? '',
    )?.toLocal();
    final expiry = expiresAt == null
        ? 'Awaiting response'
        : 'Expires ${MaterialLocalizations.of(context).formatMediumDate(expiresAt)}';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: SwipessTokens.brandOrange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isEmpty ? 'Direct Request pending' : message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$expiry · 1 token held',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white45,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: cancelling ? null : onCancel,
            child: Text(cancelling ? 'CANCELLING…' : 'CANCEL'),
          ),
        ],
      ),
    );
  }
}

class _TokenOfferCard extends StatelessWidget {
  const _TokenOfferCard({
    required this.offer,
    required this.accent,
    required this.badge,
    required this.busy,
    required this.onBuy,
  });

  final IapOffer offer;
  final Color accent;
  final String? badge;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final count = offer.tokens ?? 0;
    return SwipessTierCard(
      accentColor: accent,
      badgeLabel: badge,
      isHighlighted: badge != null,
      onTap: busy ? null : onBuy,
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
              onPressed: busy ? null : onBuy,
              child: const Text('GET'),
            ),
          ),
        ],
      ),
    );
  }
}
