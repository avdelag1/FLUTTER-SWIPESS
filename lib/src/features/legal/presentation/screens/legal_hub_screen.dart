import 'dart:ui';
import 'package:flutter/material.dart';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                const Text(
                  'LEGAL HUB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildLegalCategory(Icons.home_work_rounded, 'Landlord Issues', 'Problems with your landlord or property owner'),
                const SizedBox(height: 16),
                _buildLegalCategory(Icons.attach_money_rounded, 'Rent & Payment', 'Disputes about rent payments or charges'),
                const SizedBox(height: 16),
                _buildLegalCategory(Icons.description_rounded, 'Contract Issues', 'Problems with rental agreements or contracts'),
                
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCategory(IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 16),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
