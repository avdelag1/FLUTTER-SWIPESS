import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

# Create directories
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/insights/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/escrow/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/documents/presentation/screens"), exist_ok=True)

# File paths
price_tracker_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/insights/presentation/screens/price_tracker_screen.dart")
escrow_dashboard_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/escrow/presentation/screens/escrow_dashboard_screen.dart")
document_vault_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/documents/presentation/screens/document_vault_screen.dart")

# 1. Price Tracker Screen
price_tracker_screen_content = """import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class PriceTrackerScreen extends StatelessWidget {
  const PriceTrackerScreen({super.key});

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
                        'MARKET TRENDS',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // Chart area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Aldea Zamá Average Price', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('\$4,250', style: TextStyle(color: AppTheme.brandPrimary, fontSize: 32, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(50),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.trending_up_rounded, color: Colors.green, size: 12),
                                      SizedBox(width: 4),
                                      Text('+5.2%', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Mock Chart
                            SizedBox(
                              height: 150,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final height = 50.0 + (index * 15.0);
                                  return Container(
                                    width: 32,
                                    height: height,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Jan', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Feb', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Mar', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Apr', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('May', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Jun', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
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
}
"""

# 2. Escrow Dashboard Screen
escrow_dashboard_screen_content = """import 'package:flutter/material.dart';

class EscrowDashboardScreen extends StatelessWidget {
  const EscrowDashboardScreen({super.key});

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
                        'ESCROW VAULT',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildEscrowCard('Pending Deposit', '\$12,500', 'The Neo Penthouse', Colors.amber),
                      const SizedBox(height: 16),
                      _buildEscrowCard('Held in Escrow', '\$3,200', 'Beach Villa 4', Colors.blue),
                      const SizedBox(height: 16),
                      _buildEscrowCard('Released', '\$1,500', 'Jungle Loft', Colors.pink),
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

  Widget _buildEscrowCard(String status, String amount, String property, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(50),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(status.toUpperCase(), style: TextStyle(color: color.shade300, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
          const SizedBox(height: 16),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(property, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14)),
        ],
      ),
    );
  }
}
"""

# 3. Document Vault Screen
document_vault_screen_content = """import 'package:flutter/material.dart';

class DocumentVaultScreen extends StatelessWidget {
  const DocumentVaultScreen({super.key});

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
                        'DOCUMENT VAULT',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // Tabs
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildTab('All', true),
                      const SizedBox(width: 12),
                      _buildTab('Contracts', false),
                      const SizedBox(width: 12),
                      _buildTab('IDs', false),
                      const SizedBox(width: 12),
                      _buildTab('Fideicomiso', false),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildDocumentCard('Rental Agreement', 'Contracts • 2.4 MB', Icons.description_rounded),
                      const SizedBox(height: 16),
                      _buildDocumentCard('Passport Scan', 'IDs • 1.1 MB', Icons.badge_rounded),
                      const SizedBox(height: 16),
                      _buildDocumentCard('Property Title', 'Fideicomiso • 4.5 MB', Icons.gavel_rounded),
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

  Widget _buildTab(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isActive ? Colors.white : Colors.white.withAlpha(25)),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.download_rounded, color: Colors.white.withAlpha(100)),
        ],
      ),
    );
  }
}
"""

with open(price_tracker_screen_path, "w") as f: f.write(price_tracker_screen_content)
with open(escrow_dashboard_screen_path, "w") as f: f.write(escrow_dashboard_screen_content)
with open(document_vault_screen_path, "w") as f: f.write(document_vault_screen_content)

print("Phase 9 screens generated successfully.")
