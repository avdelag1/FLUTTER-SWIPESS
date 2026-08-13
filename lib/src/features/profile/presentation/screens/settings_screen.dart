import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/widgets/legal_sheet.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/faq_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_services_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/legal_hub_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/about_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/contact_support_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/support_dialog.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/maintenance_requests_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/perks_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/security_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor ClientSettings — SYSTEM SETTINGS with gradient action tiles.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              children: [
                _RoundBack(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEB4898),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'IDENTITY CONFIG',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEB4898),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 3.2,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'SYSTEM SETTINGS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _GroupLabel('SECURITY'),
            const SizedBox(height: 10),
            _GradTile(
              icon: Icons.shield_rounded,
              label: 'SECURITY',
              description: 'Password, 2FA protocol & blocked users',
              colors: const [Color(0xFFE4007C), Color(0xFFFF4B9F)],
              onTap: () => _push(context, const SecurityScreen()),
            ),
            _GradTile(
              icon: Icons.verified_user_rounded,
              label: 'VERIFICATION',
              description: 'Identity & resident verification flow',
              colors: const [Color(0xFFC026D3), Color(0xFFE879F9)],
              onTap: () => _push(context, const SecurityScreen(initialTab: 'verification')),
            ),
            _GradTile(
              icon: Icons.volume_up_rounded,
              label: 'PREFERENCES',
              description: 'Sounds, haptics & theme prefs',
              colors: const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              onTap: () => _push(context, const SecurityScreen(initialTab: 'preferences')),
            ),
            _GradTile(
              icon: Icons.public_rounded,
              label: 'LANGUAGE',
              description: 'EN / ES locale toggle',
              colors: const [Color(0xFF3730A3), Color(0xFF818CF8)],
              onTap: () => _push(context, const SecurityScreen(initialTab: 'language')),
            ),
            const SizedBox(height: 22),
            _GroupLabel('CONTRACTS & SERVICES'),
            const SizedBox(height: 10),
            _GradTile(
              icon: Icons.handyman_rounded,
              label: 'MAINTENANCE',
              description: 'Report & track property issues',
              colors: const [Color(0xFF2DD4BF), Color(0xFF5EEAD4)],
              onTap: () => _push(context, const MaintenanceRequestsScreen()),
            ),
            _GradTile(
              icon: Icons.description_rounded,
              label: 'CONTRACTS',
              description: 'Digital contracts vault',
              colors: const [Color(0xFFF43F5E), Color(0xFFFB7185)],
              onTap: () => _push(context, const LegalHubScreen()),
            ),
            _GradTile(
              icon: Icons.balance_rounded,
              label: 'LEGAL SERVICES',
              description: 'Lawyer packages & contract drafts',
              colors: const [Color(0xFF312E81), Color(0xFF6366F1)],
              onTap: () => _push(context, const LawyerServicesScreen()),
            ),
            _GradTile(
              icon: Icons.card_giftcard_rounded,
              label: 'PERKS',
              description: 'Resident offers & partner discounts',
              colors: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              onTap: () => _push(context, const PerksScreen()),
            ),
            const SizedBox(height: 22),
            _GroupLabel('HELP'),
            const SizedBox(height: 10),
            _GradTile(
              icon: Icons.help_outline_rounded,
              label: 'FAQ',
              description: 'Common questions & guidance',
              colors: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
              onTap: () => _push(context, const FAQScreen()),
            ),
            _GradTile(
              icon: Icons.info_rounded,
              label: 'ABOUT SWIPESS',
              description: 'Mission & how the protocol works',
              colors: const [Color(0xFF4C1D95), Color(0xFFA855F7)],
              onTap: () => _push(context, const AboutScreen()),
            ),
            _GradTile(
              icon: Icons.mail_outline_rounded,
              label: 'CONTACT',
              description: 'Email the Swipess team',
              colors: const [Color(0xFF64748B), Color(0xFF94A3B8)],
              onTap: () => _push(context, const ContactSupportScreen()),
            ),
            _GradTile(
              icon: Icons.support_agent_rounded,
              label: 'NEURAL SUPPORT',
              description: 'Customer Sync tickets (Cap SupportDialog)',
              colors: const [Color(0xFF7C3AED), Color(0xFFA855F7)],
              onTap: () => showSupportDialog(context),
            ),
            _GradTile(
              icon: Icons.gavel_rounded,
              label: 'TERMS & PRIVACY',
              description: 'Legal documents',
              colors: const [Color(0xFF6366F1), Color(0xFF818CF8)],
              onTap: () => showLegalSheet(context, doc: LegalDoc.terms),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => _resetPassword(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.transparent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'RESET PASSWORD',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _confirmDelete(context),
              child: Text(
                'DELETE ACCOUNT',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
          'This signs you out. Full deletion needs the account-delete Edge Function — wire that when the endpoint is ready.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await Supabase.instance.client.auth.signOut();
    }
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.4,
      ),
    );
  }
}

class _GradTile extends StatelessWidget {
  const _GradTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(colors: colors),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          description,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(210),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.transparent),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}
