import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';

import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

class TokensModal extends ConsumerWidget {
  const TokensModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 8),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hero Header
              const Icon(
                Icons.diamond_outlined,
                size: 56,
                color: Color(0xFFFF4D00),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unlock More',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tokens only activate message conversations between people. Premium packages unlock tokens PLUS uploading more listings, AI Concierge, Events, and priority placement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Token Packages
              for (final offer in IapCatalog.tokens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      AppHaptics.light();
                      final result = await ref
                          .read(paymentServiceProvider)
                          .buy(offer);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.userMessage)),
                      );
                      if (result.isSuccess) { await AppHaptics.success(); Navigator.of(context).pop(); }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withAlpha(20),
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D00).withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.toll_rounded,
                              color: Color(0xFFFF4D00),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${offer.tokens} Tokens',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                if (offer.description != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      offer.description!,
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(140),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              offer.priceLabel,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // Premium Package Button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE4007C), Color(0xFFFF4D00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D00).withAlpha(60),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      AppHaptics.medium();
                      Navigator.of(context).pop();
                      context.push(AppPaths.subscriptionPackages);
                    },
                    child: const Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Get Premium Package',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'View 3 Premium Package options and unlock all benefits.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  AppHaptics.light();
                  final result = await ref
                      .read(paymentServiceProvider)
                      .restorePurchases();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.userMessage)));
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Restore Purchases',
                  style: TextStyle(color: Colors.white.withAlpha(120)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
