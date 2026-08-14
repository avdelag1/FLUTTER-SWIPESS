import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';

class TokensModal extends ConsumerWidget {
  const TokensModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 56,
              color: Color(0xFFFFD43B),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tokens & Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Same packs as the live app — App Store on iOS, PayPal on web.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(180),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            for (final offer in IapCatalog.tokens)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: const Color(0xFF16161C),
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                    title: Text(
                      '${offer.name} · ${offer.tokens} tokens',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      offer.description ?? '',
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      offer.priceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () async {
                      final result = await ref
                          .read(paymentServiceProvider)
                          .buy(offer);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.userMessage)),
                      );
                      if (result.isSuccess) Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () async {
                  final result = await ref
                      .read(paymentServiceProvider)
                      .restorePurchases();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.userMessage)));
                },
                child: const Text(
                  'Restore Purchases',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
