import 'package:flutter/material.dart';

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
