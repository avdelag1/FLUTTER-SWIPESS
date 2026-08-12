import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/legal_sheet.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/contact_support_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
                            child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      _buildSectionTitle('ACCOUNT'),
                      _buildSettingsTile(
                        Icons.mail_outline_rounded,
                        'Contact Support',
                        'Email the Swipess team',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        Icons.lock_reset_rounded,
                        'Reset password',
                        'Send a recovery email',
                        onTap: () => _resetPassword(context),
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('LEGAL'),
                      _buildSettingsTile(
                        Icons.description_rounded,
                        'Terms of Service',
                        '',
                        onTap: () => showLegalSheet(context, doc: LegalDoc.terms),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        Icons.privacy_tip_rounded,
                        'Privacy Policy',
                        '',
                        onTap: () => showLegalSheet(context, doc: LegalDoc.privacy),
                      ),
                      const SizedBox(height: 48),
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.red.withAlpha(50)),
                          ),
                          child: const Center(
                            child: Text(
                              'DELETE ACCOUNT',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
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

  Future<void> _resetPassword(BuildContext context) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email on this account')),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovery email sent to $email')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reset: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161C),
        title: const Text('Delete account?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This signs you out. Full account deletion also needs a Supabase Edge Function / admin step — we can wire that when you provide the delete endpoint.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out')),
        );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withAlpha(127),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
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
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
