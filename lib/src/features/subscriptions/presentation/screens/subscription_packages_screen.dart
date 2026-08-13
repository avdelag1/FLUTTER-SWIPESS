import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/payment_result_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Cap SubscriptionPackages — RevenueCat offerings + native paywall + restore.
class SubscriptionPackagesScreen extends ConsumerStatefulWidget {
  const SubscriptionPackagesScreen({super.key});

  @override
  ConsumerState<SubscriptionPackagesScreen> createState() =>
      _SubscriptionPackagesScreenState();
}

class _SubscriptionPackagesScreenState
    extends ConsumerState<SubscriptionPackagesScreen> {
  bool _loading = true;
  bool _busy = false;
  List<Package> _packages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packages =
        await ref.read(paymentServiceProvider).getOfferings();
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _loading = false;
    });
  }

  Future<void> _openPaywall() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final result = await ref.read(paymentServiceProvider).presentPaywall();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == PaywallResult.purchased ||
        result == PaywallResult.restored) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaymentResultScreen(success: true),
        ),
      );
    } else if (result == PaywallResult.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Paywall unavailable — configure offerings in RevenueCat',
          ),
        ),
      );
    }
  }

  Future<void> _buy(Package package) async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final ok =
        await ref.read(paymentServiceProvider).purchasePackage(package);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaymentResultScreen(success: true),
        ),
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final ok = await ref.read(paymentServiceProvider).restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Purchases restored' : 'No previous purchases found',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'UPGRADE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : _restore,
                    child: const Text('Restore'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _PackageCard(
                          title: 'BASIC',
                          price: 'Free',
                          features: const [
                            'Unlimited Swipes',
                            '1 Active Listing',
                            'Standard Support',
                          ],
                          color: Colors.white54,
                          onSelect: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('You are on Basic')),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_packages.isEmpty)
                          _PackageCard(
                            title: 'VISIONARY PRO',
                            price: 'Open paywall',
                            features: const [
                              'Unlimited Active Listings',
                              'Advanced Analytics',
                              'Priority Messaging',
                              'Verified Badge',
                            ],
                            color: const Color(0xFFFF4D00),
                            isPopular: true,
                            onSelect: _busy ? () {} : _openPaywall,
                          )
                        else
                          for (final package in _packages) ...[
                            _PackageCard(
                              title: package.storeProduct.title
                                  .toUpperCase(),
                              price: package.storeProduct.priceString,
                              features: [
                                if (package.storeProduct.description
                                    .trim()
                                    .isNotEmpty)
                                  package.storeProduct.description,
                                package.identifier,
                              ],
                              color: const Color(0xFFFF4D00),
                              isPopular: package.packageType ==
                                  PackageType.monthly,
                              onSelect:
                                  _busy ? () {} : () => _buy(package),
                            ),
                            const SizedBox(height: 16),
                          ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _openPaywall,
                          child: const Text('Open RevenueCat paywall'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.title,
    required this.price,
    required this.features,
    required this.color,
    required this.onSelect,
    this.isPopular = false,
  });

  final String title;
  final String price;
  final List<String> features;
  final Color color;
  final bool isPopular;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isPopular ? color.withAlpha(150) : Colors.white.withAlpha(25),
          width: 1.5,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: color.withAlpha(30),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'MOST POPULAR',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onSelect,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isPopular ? color : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Center(
                child: Text(
                  'SELECT PACKAGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
