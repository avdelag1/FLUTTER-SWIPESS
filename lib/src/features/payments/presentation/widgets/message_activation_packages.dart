import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Legacy entry point retained for existing callers. The product is now one
/// universal Direct Request economy: the action determines the cost, not a
/// client/provider identity.
class MessageActivationPackages extends ConsumerWidget {
  const MessageActivationPackages({
    super.key,
    this.userRole = 'client',
    this.onClose,
  });

  /// Kept only for source compatibility. Direct Requests are role-agnostic.
  final String userRole;
  final VoidCallback? onClose;

  static const _packages = [
    _TokenPack(
      id: 'starter',
      name: 'Starter',
      tokens: 20,
      priceUsd: 9.99,
      description: '20 Direct Requests',
      tier: _PackTier.starter,
    ),
    _TokenPack(
      id: 'plus',
      name: 'Plus',
      tokens: 50,
      priceUsd: 19.99,
      description: '50 Direct Requests',
      badge: 'Most Popular Choice',
      tier: _PackTier.standard,
    ),
    _TokenPack(
      id: 'power',
      name: 'Power',
      tokens: 100,
      priceUsd: 39.99,
      description: '100 Direct Requests',
      tier: _PackTier.premium,
    ),
    _TokenPack(
      id: 'mega',
      name: 'Mega',
      tokens: 150,
      priceUsd: 49.99,
      description: '150 Direct Requests',
      badge: 'Best Value',
      tier: _PackTier.premium,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(directRequestBalanceProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 15,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 8),
                Text(
                  'SKIP THE WAIT',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Direct Requests',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Interest is free. Matches are free. Use one when something matters enough to send a priority request.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white60,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        balance.when(
          data: (b) => Text(
            '${b.available} available${b.reserved > 0 ? ' · ${b.reserved} pending' : ''}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFFBBF24),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          loading: () => const SizedBox(height: 18),
          error: (_, _) => const SizedBox(height: 18),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.replay_rounded,
                size: 19,
                color: Color(0xFFFBBF24),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'A token is only spent when the receiver accepts. Declined, cancelled or expired requests return automatically.',
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
        const SizedBox(height: 22),
        for (final pkg in _packages) ...[
          _PackCard(pack: pkg, onBuy: () => _purchase(context, ref, pkg)),
          const SizedBox(height: 14),
        ],
        TextButton(
          onPressed: () async {
            AppHaptics.selection();
            final result = await ref
                .read(paymentServiceProvider)
                .restorePurchases();
            if (!context.mounted) return;
            ref.invalidate(messagingEntitlementsProvider);
            ref.invalidate(directRequestBalanceProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.userMessage)),
            );
          },
          child: Text(
            'Restore purchases',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _purchase(
    BuildContext context,
    WidgetRef ref,
    _TokenPack pack,
  ) async {
    AppHaptics.medium();
    final offer = IapCatalog.tokenById(pack.id);
    if (offer == null) return;
    final result = await ref.read(paymentServiceProvider).buy(offer);
    if (!context.mounted) return;
    ref.invalidate(messagingEntitlementsProvider);
    ref.invalidate(directRequestBalanceProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
    if (result.isSuccess) {
      onClose?.call();
      Navigator.of(context).maybePop();
    }
  }
}

Future<void> showMessageActivationPackages(
  BuildContext context, {
  String userRole = 'client',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: MessageActivationPackages(
                    userRole: userRole,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

enum _PackTier { starter, standard, premium }

class _TokenPack {
  const _TokenPack({
    required this.id,
    required this.name,
    required this.tokens,
    required this.priceUsd,
    required this.description,
    required this.tier,
    this.badge,
  });

  final String id;
  final String name;
  final int tokens;
  final double priceUsd;
  final String description;
  final String? badge;
  final _PackTier tier;
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.onBuy});

  final _TokenPack pack;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final isPremium = pack.tier == _PackTier.premium;
    final isStandard = pack.tier == _PackTier.standard;
    final border = isPremium
        ? const Color(0xFFF59E0B).withAlpha(140)
        : isStandard
            ? Colors.white.withAlpha(55)
            : Colors.white.withAlpha(28);
    final icon = isPremium
        ? Icons.workspace_premium_rounded
        : isStandard
            ? Icons.bolt_rounded
            : Icons.flash_on_rounded;
    final iconColor = isPremium ? const Color(0xFFFBBF24) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isPremium
                ? const Color(0xFFF59E0B).withAlpha(28)
                : Colors.white.withAlpha(12),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          if (pack.badge != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isStandard
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFF59E0B).withAlpha(40),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isStandard
                      ? Colors.white.withAlpha(30)
                      : const Color(0xFFF59E0B).withAlpha(80),
                ),
              ),
              child: Text(
                pack.badge!.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: isStandard ? Colors.white : const Color(0xFFFDE68A),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            pack.name.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${pack.priceUsd.toStringAsFixed(2)} USD',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            '\$${(pack.priceUsd / pack.tokens).toStringAsFixed(2)} per Direct Request',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pack.description,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium
                    ? AppTheme.brandPrimary
                    : isStandard
                        ? Colors.white
                        : const Color(0xFF334155),
                foregroundColor: isStandard && !isPremium
                    ? Colors.black
                    : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'GET REQUESTS',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
