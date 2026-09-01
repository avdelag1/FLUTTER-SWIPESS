import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lets a person take over an admin-provisioned account with their own inbox.
/// Supabase retains the existing account and verifies the new address by email.
class ClaimAccountEmailScreen extends ConsumerStatefulWidget {
  const ClaimAccountEmailScreen({super.key});

  @override
  ConsumerState<ClaimAccountEmailScreen> createState() =>
      _ClaimAccountEmailScreenState();
}

class _ClaimAccountEmailScreenState
    extends ConsumerState<ClaimAccountEmailScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _requestedEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _requestedEmail != null;
    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CapBackButton(fallbackPath: AppPaths.clientSecurity),
                const SizedBox(height: 28),
                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4B9F), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66E4007C),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      done ? Icons.mark_email_read_rounded : Icons.key_rounded,
                      color: Colors.white,
                      size: 43,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  done ? 'CHECK YOUR INBOX' : 'MAKE IT YOURS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  done ? 'You’re almost home.' : 'Claim your Swipess account.',
                  style: AppTheme.displayItalic.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  done
                      ? 'We sent a secure confirmation to $_requestedEmail. Open it and approve the change—then this account is officially yours.'
                      : 'If this account was created for you, replace its temporary email with the real inbox you use. Your profile, listings and history stay exactly where they are.',
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                if (done) ...[
                  _InfoCard(
                    icon: Icons.verified_user_rounded,
                    title: 'One last secure step',
                    body: 'Use the confirmation link in your new inbox. Until you approve it, your current sign-in email stays active.',
                  ),
                  const SizedBox(height: 16),
                  BrandPrimaryButton(
                    label: 'Back to security',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ] else ...[
                  _InfoCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'Protected handover',
                    body: 'Enter the password you received with this account. We never reveal it or send it anywhere.',
                  ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    controller: _email,
                    hint: 'Your real email address',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: _password,
                    hint: 'Current account password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                  ),
                  const SizedBox(height: 18),
                  BrandPrimaryButton(
                    label: _busy ? 'Sending confirmation…' : 'Claim my account',
                    icon: Icons.rocket_launch_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : _claim,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Use an inbox you control. The confirmation email is the final proof that the account belongs to you.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.faint(context),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _claim() async {
    final email = _email.text.trim().toLowerCase();
    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!validEmail) {
      _show('Enter a real email address first.');
      return;
    }
    if (_password.text.isEmpty) {
      _show('Enter the current account password first.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestEmailChange(currentPassword: _password.text, newEmail: email);
      if (!mounted) return;
      setState(() => _requestedEmail = email);
    } catch (error) {
      if (mounted) _show('We could not send that confirmation: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.brandPrimary.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.brandPrimary, size: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.ink(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 12,
                    height: 1.45,
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
