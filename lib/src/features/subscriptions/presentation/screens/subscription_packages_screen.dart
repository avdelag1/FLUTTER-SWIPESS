import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/payment_result_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionPackagesScreen extends StatelessWidget {
  const SubscriptionPackagesScreen({super.key});

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
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(40)),
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
                ],
              ),
            ),
            Expanded(
              child: ListView(
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
                        const SnackBar(content: Text('You are on Basic')),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _PackageCard(
                    title: 'VISIONARY PRO',
                    price: '\$29/mo',
                    features: const [
                      'Unlimited Active Listings',
                      'Advanced Analytics',
                      'Priority Messaging',
                      'Verified Badge',
                    ],
                    color: const Color(0xFFFF4D00),
                    isPopular: true,
                    onSelect: () {
                      HapticFeedback.mediumImpact();
                      // RevenueCat keys deferred — show success shell for flow parity.
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PaymentResultScreen(success: true),
                        ),
                      );
                    },
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
        color: Colors.white.withAlpha(12),
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
                  Text(
                    f,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
