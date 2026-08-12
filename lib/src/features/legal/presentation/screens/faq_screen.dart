import 'package:flutter/material.dart';

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
