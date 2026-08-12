import 'package:flutter/material.dart';

class SubscriptionPackagesScreen extends StatelessWidget {
  const SubscriptionPackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
              children: [
                // Header
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
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'UPGRADE',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildPackageCard(
                        title: 'BASIC',
                        price: 'Free',
                        features: ['Unlimited Swipes', '1 Active Listing', 'Standard Support'],
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 24),
                      _buildPackageCard(
                        title: 'VISIONARY PRO',
                        price: '\$29/mo',
                        features: ['Unlimited Active Listings', 'Advanced Analytics', 'Priority Messaging', 'Verified Badge'],
                        color: const Color(0xFFFF4D00),
                        isPopular: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard({required String title, required String price, required List<String> features, required Color color, bool isPopular = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isPopular ? color.withAlpha(150) : Colors.white.withAlpha(25), width: 1.5),
        boxShadow: isPopular ? [BoxShadow(color: color.withAlpha(30), blurRadius: 40, offset: const Offset(0, 10))] : [],
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
              child: Text('MOST POPULAR', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: color, size: 20),
                const SizedBox(width: 12),
                Text(f, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isPopular ? color : Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Center(
              child: Text('SELECT PACKAGE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
