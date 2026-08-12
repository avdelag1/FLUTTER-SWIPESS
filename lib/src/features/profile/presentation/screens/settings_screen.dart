import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        'SETTINGS',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      _buildSectionTitle('ACCOUNT'),
                      _buildSettingsTile(Icons.shield_rounded, 'Account Security', 'Password & 2FA'),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.credit_card_rounded, 'Payment Methods', 'Manage billing'),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.block_rounded, 'Blocked Users', 'Manage blocking'),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('PREFERENCES'),
                      _buildSettingsTile(Icons.volume_up_rounded, 'Swipe Sounds', 'Haptics & audio'),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.language_rounded, 'Language', 'English (US)'),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('LEGAL'),
                      _buildSettingsTile(Icons.description_rounded, 'Terms of Service', ''),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.privacy_tip_rounded, 'Privacy Policy', ''),
                      
                      const SizedBox(height: 48),
                      // Delete Account
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.red.withAlpha(50)),
                        ),
                        child: const Center(
                          child: Text(
                            'DELETE ACCOUNT',
                            style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.brandPrimary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
