import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Header
              Text(
                'TOKENS',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tokens activate messaging, unlock priority listing placement, and power the AI Concierge.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Scrollable Packages
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: IapCatalog.tokens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final offer = IapCatalog.tokens[index];
                    final isPopular = index == 1; // Highlight the middle one
                    return _TokenPackageCard(
                      offer: offer,
                      isPopular: isPopular,
                      onTap: () async {
                        AppHaptics.light();
                        final result = await ref
                            .read(paymentServiceProvider)
                            .buy(offer);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.userMessage)),
                        );
                        ref.invalidate(messagingEntitlementsProvider);
                        if (result.isSuccess) {
                          await AppHaptics.success();
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Premium Upsell Button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFE4007C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE4007C).withAlpha(50),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      AppHaptics.medium();
                      if (context.mounted) Navigator.of(context).pop();
                      context.push(AppPaths.subscriptionPackages);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UNLOCK PREMIUM',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Get unlimited tokens & features',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withAlpha(200),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () async {
                    AppHaptics.light();
                    final result = await ref
                        .read(paymentServiceProvider)
                        .restorePurchases();
                    if (!context.mounted) return;
                    ref.invalidate(messagingEntitlementsProvider);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(result.userMessage)));
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenPackageCard extends StatelessWidget {
  const _TokenPackageCard({
    required this.offer,
    required this.onTap,
    this.isPopular = false,
  });

  final IapOffer offer;
  final VoidCallback onTap;
  final bool isPopular;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(isPopular ? 160 : 80),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPopular
                ? const Color(0xFFFFB300)
                : Colors.white.withAlpha(30),
            width: isPopular ? 2.0 : 1.0,
          ),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withAlpha(40),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFB300).withAlpha(isPopular ? 255 : 120),
                    const Color(0xFFFF4D00).withAlpha(isPopular ? 255 : 120),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: isPopular
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF4D00).withAlpha(100),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${offer.tokens}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TOKENS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  if (offer.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      offer.description!,
                      style: GoogleFonts.plusJakartaSans(
                        color: isPopular
                            ? const Color(0xFFFFB300)
                            : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Price Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isPopular ? const Color(0xFFFFB300) : Colors.white10,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                offer.priceLabel,
                style: GoogleFonts.plusJakartaSans(
                  color: isPopular ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
