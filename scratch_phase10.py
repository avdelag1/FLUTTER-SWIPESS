import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

# Create directories
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/subscriptions/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/legal/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/profile/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/insights/presentation/screens"), exist_ok=True)

# File paths
sub_packages_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/subscriptions/presentation/screens/subscription_packages_screen.dart")
faq_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/legal/presentation/screens/faq_screen.dart")
maintenance_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/profile/presentation/screens/maintenance_requests_screen.dart")
local_intel_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/insights/presentation/screens/local_intel_screen.dart")

# 1. Subscription Packages Screen
sub_packages_screen_content = """import 'package:flutter/material.dart';

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
"""

# 2. FAQ Screen
faq_screen_content = """import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

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
                        'FAQ',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildFAQItem('How does escrow work?', 'Swipess securely holds your funds until the transaction or lease is fully verified, protecting both parties.'),
                      _buildFAQItem('What is a Visionary Pro account?', 'It is our premium subscription that grants you verified badges, advanced analytics, and unlimited listings.'),
                      _buildFAQItem('How do I list my property?', 'Simply switch to Owner Mode in your Profile and tap the "Add Listing" button to get started.'),
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

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        children: [
          Text(answer, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
"""

# 3. Maintenance Requests Screen
maintenance_screen_content = """import 'package:flutter/material.dart';

class MaintenanceRequestsScreen extends StatelessWidget {
  const MaintenanceRequestsScreen({super.key});

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
                        'MAINTENANCE',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildTicket('AC Not Cooling', 'The Neo Penthouse', 'In Progress', Colors.amber),
                      const SizedBox(height: 16),
                      _buildTicket('Leaking Sink', 'Beach Villa 4', 'Resolved', Colors.green),
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

  Widget _buildTicket(String issue, String location, String status, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(100)),
        boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(issue, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withAlpha(50), borderRadius: BorderRadius.circular(999)),
                child: Text(status.toUpperCase(), style: TextStyle(color: color.shade300, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(location, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14)),
        ],
      ),
    );
  }
}
"""

# 4. Local Intel Screen
local_intel_screen_content = """import 'package:flutter/material.dart';

class LocalIntelScreen extends StatelessWidget {
  const LocalIntelScreen({super.key});

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
                        'LOCAL INTEL',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(24),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildIntelCard('Safety Score', '92/100', Icons.shield_rounded, Colors.green),
                      _buildIntelCard('Walkability', '85/100', Icons.directions_walk_rounded, Colors.blue),
                      _buildIntelCard('Nightlife', '98/100', Icons.nightlife_rounded, Colors.purple),
                      _buildIntelCard('Restaurants', '140+', Icons.restaurant_rounded, Colors.amber),
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

  Widget _buildIntelCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color.shade300, size: 32),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
        ],
      ),
    );
  }
}
"""

with open(sub_packages_screen_path, "w") as f: f.write(sub_packages_screen_content)
with open(faq_screen_path, "w") as f: f.write(faq_screen_content)
with open(maintenance_screen_path, "w") as f: f.write(maintenance_screen_content)
with open(local_intel_screen_path, "w") as f: f.write(local_intel_screen_content)

print("Phase 10 screens generated successfully.")
