import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.userMessage)));
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final result = await ref.read(paymentServiceProvider).restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(messagingEntitlementsProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.userMessage)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: AmbientPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: MatteSurface.ink(context).withAlpha(10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MatteSurface.ink(context).withAlpha(30),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: MatteSurface.ink(context),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy ? null : _restore,
                      child: Text(
                        'Restore',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.ink(context).withAlpha(150),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  children: [
                    Text(
                      'GO PREMIUM',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.ink(context),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock the ultimate Swipess experience. Priority placement, unlimited AI, and no messaging limits.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.ink(context).withAlpha(180),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    for (final offer in IapCatalog.subscriptions) ...[
                      _PremiumPackageCard(
                        title: (offer.label ?? offer.name).toUpperCase(),
                        price: offer.priceLabel,
                        duration: offer.durationLabel ?? '',
                        features: offer.benefits,
                        color: const Color(0xFFE4007C),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFE4007C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        isPopular: offer.popular,
                        onSelect: _busy ? () {} : () => _buy(offer),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _BasicPackageCard(
                      title: 'BASIC',
                      price: 'Free',
                      features: const [
                        'Unlimited Swipes',
                        '1 Active Listing',
                        'Standard Support',
                      ],
                      onSelect: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You are on Basic')),
                        );
                      },
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

class _PremiumPackageCard extends StatelessWidget {
  const _PremiumPackageCard({
    required this.title,
    required this.price,
    required this.duration,
    required this.features,
    required this.color,
    required this.gradient,
    required this.onSelect,
    this.isPopular = false,
  });

  final String title;
  final String price;
  final String duration;
  final List<String> features;
  final Color color;
  final Gradient gradient;
  final bool isPopular;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPopular ? gradient : null,
        color: isPopular ? null : MatteSurface.ink(context).withAlpha(10),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: isPopular
              ? Colors.transparent
              : MatteSurface.ink(context).withAlpha(20),
          width: 2,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: color.withAlpha(80),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'MOST POPULAR',
                      style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: isPopular
                        ? Colors.white70
                        : MatteSurface.ink(context).withAlpha(150),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.plusJakartaSans(
                        color: isPopular
                            ? Colors.white
                            : MatteSurface.ink(context),
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        duration,
                        style: GoogleFonts.plusJakartaSans(
                          color: isPopular
                              ? Colors.white70
                              : MatteSurface.ink(context).withAlpha(150),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                for (final f in features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isPopular
                                ? Colors.white24
                                : color.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: isPopular ? Colors.white : color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            f,
                            style: GoogleFonts.plusJakartaSans(
                              color: isPopular
                                  ? Colors.white
                                  : MatteSurface.ink(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: isPopular ? Colors.white : MatteSurface.ink(context),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isPopular
                        ? [
                            BoxShadow(
                              color: Colors.white.withAlpha(50),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'SELECT PACKAGE',
                      style: GoogleFonts.plusJakartaSans(
                        color: isPopular ? color : MatteSurface.canvas(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BasicPackageCard extends StatelessWidget {
  const _BasicPackageCard({
    required this.title,
    required this.price,
    required this.features,
    required this.onSelect,
  });

  final String title;
  final String price;
  final List<String> features;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: MatteSurface.ink(context).withAlpha(20),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.ink(context).withAlpha(150),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.ink(context),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: MatteSurface.ink(context).withAlpha(100),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.ink(context).withAlpha(200),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSelect,
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              'CURRENT PLAN',
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.ink(context).withAlpha(150),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
